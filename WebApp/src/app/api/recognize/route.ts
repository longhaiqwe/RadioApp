export const runtime = "nodejs";

const MACOS_DOWNLOAD_URL =
  "https://longhaixueai-1258687935.cos.ap-guangzhou.myqcloud.com/downloads/ShiyinFM-0.1.6-build7-universal.dmg";

const WEB_RECOGNITION_DISABLED_MESSAGE =
  "Web 版暂不提供听歌识曲，请下载 macOS 客户端使用完整识曲。";

export async function POST() {
  return Response.json(
    {
      error: WEB_RECOGNITION_DISABLED_MESSAGE,
      downloadUrl: MACOS_DOWNLOAD_URL,
    },
    { status: 410 }
  );
}
