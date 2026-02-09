import Foundation

/// 简单的 MPEG-TS 解包器，用于提取 AAC 音频数据
class TSUnpacker {
    
    /// 从 TS 数据中解包出音频数据 (AAC/ADTS)
    static func extractAudio(from tsData: Data) -> Data {
        var audioData = Data()
        var payloadData = Data()
        
        // 1. 简单的 PID 统计，找到数据量最大的 PID (通常是音频/视频)
        // 省略复杂的 PAT/PMT 解析，直接盲猜 PID
        // 或者是直接提取所有 Payload (如果不区分 PID)
        
        let packetSize = 188
        guard tsData.count >= packetSize else { return Data() }
        
        var offset = 0
        var pidCounts: [Int: Int] = [:]
        
        // 第一遍：统计 PID，找到主音频流
        while offset + packetSize <= tsData.count {
            // 检查 Sync Byte (0x47)
            if tsData[offset] != 0x47 {
                // 如果不同步，尝试向前搜寻
                offset += 1
                continue
            }
            
            let header2 = tsData[offset + 1]
            let header3 = tsData[offset + 2]
            
            // PID: 13 bits
            // header2: TEI(1) PUSI(1) Priority(1) PID_HI(5)
            // header3: PID_LO(8)
            let pid = ((Int(header2) & 0x1F) << 8) | Int(header3)
            
            // 忽略常见控制 PID
            if pid != 0 && pid != 17 && pid != 0x1FFF { // PAT, SDT, Null
                pidCounts[pid, default: 0] += 1
            }
            
            offset += packetSize
        }
        
        // 找到出现次数最多的前 5 个 PID
        let topPIDs = pidCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        
        var audioPid: Int?
        
        // 遍历前几个候选 PID，检查是否包含 ADTS 特征 (0xFFF)
        for pid in topPIDs {
            if isAudioPID(pid, in: tsData, packetSize: packetSize) {
                audioPid = pid
                print("TSUnpacker: 选定音频 PID: \(pid) (经 ADTS 验证)")
                break
            }
        }
        
        // 如果没找到特征码，回退到数量最多的那个 (即使可能是视频，也比没有强)
        if audioPid == nil {
            if let maxPid = topPIDs.first {
                print("TSUnpacker: 未检测到 ADTS 特征，回退到包数量最多的 PID: \(maxPid)")
                audioPid = maxPid
            }
        }
        
        guard let finalAudioPid = audioPid else {
            print("TSUnpacker: 未找到有效 PID")
            return Data()
        }
        
        let audioPidValue = finalAudioPid // distinct name to avoid confusion in closure

        
        // 第二遍：提取 Payload
        offset = 0
        while offset + packetSize <= tsData.count {
            if tsData[offset] != 0x47 {
                offset += 1
                continue
            }
            
            let header2 = tsData[offset + 1]
            let header3 = tsData[offset + 2]
            let header4 = tsData[offset + 3]
            
            let pid = ((Int(header2) & 0x1F) << 8) | Int(header3)
            
            if pid == finalAudioPid {
                let adaptationFieldControl = (header4 & 0x30) >> 4
                var payloadOffset = 4
                
                // Adaptation Field
                if adaptationFieldControl == 2 || adaptationFieldControl == 3 {
                    // Adaptation field length
                    if offset + 4 < tsData.count {
                        let adaptationLength = Int(tsData[offset + 4])
                        payloadOffset += 1 + adaptationLength
                    }
                }
                
                // 如果有 Payload 且偏移量在包内
                if (adaptationFieldControl == 1 || adaptationFieldControl == 3) && payloadOffset < packetSize {
                    let chunk = tsData.subdata(in: (offset + payloadOffset)..<(offset + packetSize))
                    payloadData.append(chunk)
                }
            }
            
            offset += packetSize
        }
        
        // 2. 剥离 PES 头 (Packetized Elementary Stream)
        // PayloadData 是一个 PES 包序列。每个 PES 包以 00 00 01 开头
        // 我们需要遍历 PayloadData，找到 PES 头并跳过
        
        var cursor = 0
        while cursor + 6 < payloadData.count {
            // 查找 Start Code 0x000001
            if payloadData[cursor] == 0x00 && payloadData[cursor+1] == 0x00 && payloadData[cursor+2] == 0x01 {
                let streamId = payloadData[cursor+3]
                
                // 音频流 ID 通常是 0xC0-0xDF
                // 或者是 0xBD (Private Stream 1)
                // 简单起见，只要是合法的 PES 头，我们就尝试解析
                
                // PES Packet Length (2 bytes)
                // let packetLength = (Int(payloadData[cursor+4]) << 8) | Int(payloadData[cursor+5])
                // 注意：音频的 packetLength 可能是 0 (未指定) 或具体长度
                // 但在这里我们有一整块数据，所以不好依赖 packetLength 来跳过整个包
                // 我们主要是为了跳过 "PES Header" 本身
                
                // 解析 PES Header 长度
                // 标准 PES 头后面可能有扩展
                // 6 bytes fixed header: 00 00 01 ID LEN_H LEN_L
                // 如果是 Audio (0xC0-0xDF)，后面通常跟着可选头
                
                if (streamId >= 0xC0 && streamId <= 0xDF) || streamId == 0xBD {
                    // PES Header Data Length is at offset 8
                    if cursor + 9 < payloadData.count {
                        // skip: 00 00 01 ID LenH LenL (6 bytes)
                        // plus: Flags(1) Flags(1) HeaderLen(1)
                        // let flags2 = payloadData[cursor+7]
                        let headerDataLen = Int(payloadData[cursor+8])
                        
                        let totalHeaderLen = 6 + 3 + headerDataLen
                        
                        // 提取实际音频数据
                        // 音频数据通常持续到下一个 00 00 01
                        // 或者我们直接把数据追加进去?
                        // 由于我们已经是连续的 Payload，PES 包是紧接着的
                        
                        // 这里有个问题：如果不按包解析，很难知道哪里是数据结束
                        // 但我们可以简单地：找到当前 PES 头，跳过头，把所有内容视为数据，直到下一个 00 00 01
                        
                        let dataStart = cursor + totalHeaderLen
                        
                        // 寻找下一个 Start Code
                        var nextStart = payloadData.count
                        // 简单的向后搜索 (低效但有效)
                        // 为了性能，可以跳过一些字节
                        var scan = dataStart
                        while scan + 3 < payloadData.count {
                            if payloadData[scan] == 0x00 && payloadData[scan+1] == 0x00 && payloadData[scan+2] == 0x01 {
                                nextStart = scan
                                break
                            }
                            scan += 1
                        }
                        
                        if dataStart < nextStart {
                            let esChunk = payloadData.subdata(in: dataStart..<nextStart)
                            audioData.append(esChunk)
                        }
                        
                        cursor = nextStart
                        continue
                    }
                }
            }
            
            // 如果没匹配到 Start Code，cursor + 1
            cursor += 1
        }
        
        // 如果处理后没有数据（比如解析失败），为了保底，返回原始 Payload
        // 或者是如果 Payload 看起来已经是 ADTS (FF Fx)，就直接返回 Payload
        if audioData.count < 100 && payloadData.count > 1000 {
            // 检查是否有 ADTS Sync
            if hasADTSSync(payloadData) {
                print("TSUnpacker: PES 解析未获得数据，但 Payload 包含 ADTS，直接使用 Payload")
                return payloadData
            }
        }
        
        if audioData.isEmpty { 
            print("TSUnpacker: 未提取到音频数据")
            return payloadData // Fallback: try raw payload
        }
        
        print("TSUnpacker: 成功提取 AAC 数据: \(audioData.count) bytes (from TS: \(tsData.count))")
        
        // 3. 数据清洗 (Sanitize)
        // 很多时候 TS 提取出的 AAC 数据在拼接处会有坏帧或者垃圾数据，导致 AVAudioFile 读到一半就停止
        // 我们手动遍历一遍 ADTS 帧，只保留有效的帧
        let sanitizedData = sanitizeADTS(data: audioData)
        print("TSUnpacker: 数据清洗完成: \(sanitizedData.count) bytes (原始: \(audioData.count))")
        
        return sanitizedData
    }
    
    /// 清洗 ADTS 数据，移除无效字节，确保帧的连续性
    private static func sanitizeADTS(data: Data) -> Data {
        var cleanData = Data()
        var offset = 0
        let totalSize = data.count
        
        while offset < totalSize - 7 { // Header is at least 7 bytes
            // 查找 Sync Word (0xFFF)
            if data[offset] != 0xFF || (data[offset + 1] & 0xF0) != 0xF0 {
                offset += 1
                continue
            }
            
            // 解析帧长 (13 bits starting at bit 30)
            // Byte 3 (last 2 bits) + Byte 4 (8 bits) + Byte 5 (first 3 bits)
            let b3 = Int(data[offset + 3])
            let b4 = Int(data[offset + 4])
            let b5 = Int(data[offset + 5])
            
            let frameLength = ((b3 & 0x03) << 11) | (b4 << 3) | ((b5 & 0xE0) >> 5)
            
            // 简单的合法性检查
            if frameLength < 7 || offset + frameLength > totalSize {
                // 帧长异常或超出文件范围，视为无效，跳过一个字节继续搜
                offset += 1
                continue
            }
            
            // 严格模式：验证下一帧的 Sync Word (如果存在)
            // 防止误判 (0xFF F0 在数据中出现是有可能的)
            let nextOffset = offset + frameLength
            if nextOffset + 1 < totalSize {
                // 检查下一帧是否也是 Sync Word
                if data[nextOffset] != 0xFF || (data[nextOffset + 1] & 0xF0) != 0xF0 {
                    // 下一帧头不对，说明当前这个 Header 可能是误判
                    // 或者数据流确实坏了。保守起见，我们要么丢弃这一帧，要么尝试保留
                    // 这里我们采取由于是连续流，通常是紧密排列的策略
                    // 如果下一帧不对，我们假设当前是误判，跳过
                    offset += 1
                    continue
                }
            }
            
            // 这是一个看起来合法的帧，复制过去
            let frameData = data.subdata(in: offset..<nextOffset)
            cleanData.append(frameData)
            
            // 跳到下一帧
            offset = nextOffset
        }
        
        return cleanData
    }
    
    private static func hasADTSSync(_ data: Data) -> Bool {
        // 简单的检查前 1000 字节是否有 FFF
        let limit = min(data.count - 1, 1000)
        for i in 0..<limit {
            if data[i] == 0xFF && (data[i+1] & 0xF0) == 0xF0 {
                return true
            }
        }
        return false
    }
    
    /// 检查指定 PID 的 Payload 是否看起来像 AAC 音频
    private static func isAudioPID(_ targetPid: Int, in tsData: Data, packetSize: Int) -> Bool {
        var offset = 0
        var foundPayloads = 0
        var maxCheck = 20 // 只检查前 20 个包，提高效率
        
        while offset + packetSize <= tsData.count && foundPayloads < maxCheck {
            if tsData[offset] != 0x47 {
                offset += 1
                continue
            }
            
            let header2 = tsData[offset + 1]
            let header3 = tsData[offset + 2]
            let header4 = tsData[offset + 3]
            
            let pid = ((Int(header2) & 0x1F) << 8) | Int(header3)
            
            if pid == targetPid {
                foundPayloads += 1
                
                let adaptationFieldControl = (header4 & 0x30) >> 4
                var payloadOffset = 4
                
                if adaptationFieldControl == 2 || adaptationFieldControl == 3 {
                    if offset + 4 < tsData.count {
                        let adaptationLength = Int(tsData[offset + 4])
                        payloadOffset += 1 + adaptationLength
                    }
                }
                
                if (adaptationFieldControl == 1 || adaptationFieldControl == 3) && payloadOffset < packetSize {
                    // Check for ADTS Sync (0xFFF) anywhere in the first few bytes of payload
                    // Or even better, check if PUSI is set (Payload Unit Start Indicator) and then check PES header?
                    // Let's just scan the payload for 0xFFF
                    
                    let limit = min(packetSize, offset + packetSize)
                    let start = offset + payloadOffset
                    
                    if start + 1 < limit {
                        for i in start..<(limit - 1) {
                            if tsData[i] == 0xFF && (tsData[i+1] & 0xF0) == 0xF0 {
                                return true
                            }
                        }
                    }
                }
            }
            
            offset += packetSize
        }
        
        return false
    }
}
