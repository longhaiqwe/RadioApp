//
//  RadioAppWidgetLiveActivity.swift
//  RadioAppWidget
//
//  Created by longhai on 2026/2/14.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RadioAppWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicRecognitionAttributes.self) { context in
            // Lock screen/banner UI
            VStack(alignment: .leading) {
                HStack {
                    if context.state.state == .listening {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title)
                            .foregroundColor(.accentColor)
                            // Use iOS 17 compatible animation if available, or fallback/simplify
                            .symbolEffect(.variableColor)
                        
                        VStack(alignment: .leading) {
                            Text("正在聆听...")
                                .font(.headline)
                            Text(context.attributes.stationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if context.state.state == .success {
                        // Artwork
                        if let url = context.state.coverImageURL {
                            // Using AsyncImage for basic network loading
                            // Note: Widget environment has limitations, this might be slow
                             NetworkImage(url: url)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                        } else {
                            Image(systemName: "music.note")
                                .font(.largeTitle)
                                .frame(width: 50, height: 50)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(context.state.songTitle ?? "未知歌曲")
                                .font(.headline)
                                .lineLimit(1)
                            Text(context.state.artistName ?? "未知歌手")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("未识别到歌曲")
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .padding()
            }
            .activityBackgroundTint(Color(UIColor.systemBackground))
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.state == .success, let url = context.state.coverImageURL {
                         NetworkImage(url: url)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    } else {
                        Image(systemName: "waveform")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.state == .listening {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.accentColor)
                    } else {
                        // Could put a small icon or action here
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.state == .listening {
                        HStack {
                            Text("正在聆听...")
                                .font(.headline)
                            Spacer()
                            // Mocking waveform
                            Image(systemName: "waveform.path.ecg")
                                .symbolEffect(.variableColor)
                        }
                    } else if context.state.state == .success {
                        VStack(alignment: .leading) {
                            Text(context.state.songTitle ?? "未知歌曲")
                                .font(.headline)
                                .lineLimit(1)
                            Text(context.state.artistName ?? "未知歌手")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("未识别")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
            } compactLeading: {
                if context.state.state == .listening {
                    Image(systemName: "waveform")
                        .foregroundColor(.accentColor)
                } else if context.state.state == .success {
                    // Small cover if possible, or music note
                    Image(systemName: "music.note")
                        .foregroundColor(.accentColor)
                }
            } compactTrailing: {
                if context.state.state == .listening {
                    Text("聆听中")
                        .font(.caption2)
                } else if context.state.state == .success {
                    Text("已找到")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            } minimal: {
                if context.state.state == .listening {
                    Image(systemName: "waveform")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "music.note")
                }
            }
            .widgetURL(URL(string: "radioapp://recognition"))
            .keylineTint(Color.accentColor)
        }
    }
}

// Simple NetworkImage helper for Widgets/Live Activities
// Note: iOS 15+ supports AsyncImage, but error handling is minimal.
struct NetworkImage: View {
    let url: URL
    
    var body: some View {
        if #available(iOS 15.0, *) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.3)
                case .success(let image):
                    image.resizable()
                case .failure:
                    Image(systemName: "music.note.list")
                        .foregroundColor(.gray)
                @unknown default:
                    Color.gray
                }
            }
        } else {
            Color.gray
        }
    }
}
