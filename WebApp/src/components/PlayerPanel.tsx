"use client";

import {
  Download,
  ExternalLink,
  Heart,
  ListMusic,
  Loader2,
  Pause,
  Play,
  SkipBack,
  SkipForward,
  Share2,
  Sparkles,
  ChevronDown,
  X,
} from "lucide-react";
import Image from "next/image";
import { useEffect, useMemo, useState, type MouseEvent } from "react";
import { useAudioPlayer } from "@/features/player/AudioPlayerProvider";
import type {
  RecognitionResult,
  RecognizedSongVersion,
  SongCandidate,
  SyncedLyrics,
} from "@/features/recognition/recognitionTypes";
import type { Station } from "@/features/stations/stationTypes";
import { makeMusicPlatformTargets } from "@/lib/musicPlatformLinks";
import {
  createShareCardSvgDataUrl,
  downloadShareCard,
  formatReleaseMemory,
  makeArtworkProxyUrl,
  prepareShareCardData,
  shareOrDownloadShareCard,
  type ShareCardData,
} from "@/lib/shareCardImage";
import { IconButton } from "./IconButton";
import { StationAvatar } from "./StationAvatar";
import { SyncedLyricsPanel } from "./SyncedLyricsPanel";

const MACOS_DOWNLOAD_URL =
  "https://longhaixueai-1258687935.cos.ap-guangzhou.myqcloud.com/downloads/ShiyinFM-0.1.6-build7-universal.dmg";

type RecognitionPanelState = {
  status: "idle" | "loading" | "success" | "error";
  result: RecognitionResult | null;
  error: string | null;
  startedAt?: number;
};

type PlayerPanelProps = {
  isFavorite: boolean;
  onToggleFavorite: (station: Station) => void;
  recognition: RecognitionPanelState;
  onRecognize: () => void;
  onDismissRecognition: () => void;
};

export function PlayerPanel({
  isFavorite,
  onToggleFavorite,
  recognition,
  onRecognize,
  onDismissRecognition,
}: PlayerPanelProps) {
  const [isPlaylistOpen, setIsPlaylistOpen] = useState(false);
  const {
    state,
    togglePlayPause,
    previous,
    next,
    setVolume,
    setExpanded,
    playStation,
  } = useAudioPlayer();

  const shouldLockPageScroll = state.isExpanded && Boolean(state.currentStation);

  useEffect(() => {
    if (!shouldLockPageScroll) return;

    const previousBodyOverflow = document.body.style.overflow;
    const previousDocumentOverflow = document.documentElement.style.overflow;

    document.body.style.overflow = "hidden";
    document.documentElement.style.overflow = "hidden";

    return () => {
      document.body.style.overflow = previousBodyOverflow;
      document.documentElement.style.overflow = previousDocumentOverflow;
    };
  }, [shouldLockPageScroll]);

  if (!state.isExpanded || !state.currentStation) return null;

  const currentStation = state.currentStation;
  const currentPlaylist =
    state.playlist.length > 0 ? state.playlist : [currentStation];
  const stationSubtitle = currentStation.tags || currentStation.country;
  const recognizedResult =
    recognition.status === "success" ? recognition.result : null;
  const hasRecognitionView = recognition.status !== "idle";
  const closePanel = () => {
    if (hasRecognitionView) {
      onDismissRecognition();
      return;
    }

    setExpanded(false);
  };

  return (
    <div
      role="dialog"
      aria-label="播放器"
      className="fixed inset-0 z-50 h-[100dvh] overflow-hidden bg-[rgba(10,10,15,0.97)] text-white backdrop-blur-2xl"
    >
      <div
        aria-hidden="true"
        className="absolute inset-x-0 top-0 h-[40vh] rounded-b-[4rem] bg-[radial-gradient(circle_at_center_top,rgba(131,56,236,0.52),rgba(255,0,110,0.17)_48%,rgba(10,10,15,0)_78%)]"
      />
      <div className="relative mx-auto flex h-full max-w-4xl flex-col px-5 pb-5 pt-4 sm:px-8">
        <div className="flex items-center justify-between">
          <div className="w-11" aria-hidden="true" />
          <RecognitionAction onRecognize={onRecognize} />
          <IconButton
            label={hasRecognitionView ? "关闭识别结果" : "关闭播放器"}
            onClick={closePanel}
          >
            <X size={20} />
          </IconButton>
        </div>

        <div
          data-testid="player-panel-scroll-frame"
          className={`scrollbar-none flex min-h-0 flex-1 flex-col items-center justify-between overflow-x-hidden overflow-y-auto pb-3 text-center ${
            recognizedResult ? "gap-4 pt-5" : "gap-5 pt-7 sm:pt-9"
          }`}
        >
          {recognizedResult ? (
            <RecognizedSongExperience
              result={recognizedResult}
              recognitionStartedAt={recognition.startedAt}
              stationName={currentStation.name}
            />
          ) : (
            <div className="flex w-full flex-col items-center gap-5">
              <div className="grid h-52 w-52 place-items-center rounded-full bg-[radial-gradient(circle,rgba(131,56,236,0.82)_0%,rgba(85,31,137,0.68)_58%,rgba(36,18,58,0.3)_72%,rgba(36,18,58,0)_74%)] shadow-[0_0_36px_rgba(131,56,236,0.28)] sm:h-60 sm:w-60">
                <div className="grid h-32 w-32 place-items-center rounded-full bg-white/95 shadow-[0_0_20px_rgba(255,255,255,0.14)] sm:h-36 sm:w-36">
                  <StationAvatar
                    name={currentStation.name}
                    stationId={currentStation.id}
                    favicon={currentStation.favicon}
                    sizeClassName="h-24 w-24 sm:h-28 sm:w-28"
                  />
                </div>
              </div>

              <PlayerVisualizer />

              <div>
                <h2 className="text-xl font-bold leading-tight text-white sm:text-2xl">
                  {currentStation.name}
                </h2>
                <p className="mt-2 text-xs font-medium text-[var(--neon-cyan)] sm:text-sm">
                  {stationSubtitle}
                </p>
                {state.playbackError ? (
                  <p className="mt-4 rounded-full border border-[rgba(255,59,48,0.35)] bg-[rgba(255,59,48,0.12)] px-4 py-2 text-sm text-white/80">
                    {state.playbackError}
                  </p>
                ) : null}
              </div>

              <RecognitionStatusPanel recognition={recognition} />
            </div>
          )}

          <div className="flex w-full flex-col items-center gap-4">
            <div
              role="group"
              aria-label="播放控制"
              className="grid w-full max-w-lg grid-cols-[1fr_1fr_5rem_1fr_1fr] items-center justify-items-center gap-2"
            >
              <IconButton
                label={isFavorite ? "取消收藏" : "收藏"}
                active={isFavorite}
                onClick={() => onToggleFavorite(currentStation)}
                className="h-11 w-11 border-transparent bg-transparent text-white/70 hover:bg-white/5 sm:h-12 sm:w-12"
              >
                <Heart size={26} fill={isFavorite ? "currentColor" : "none"} />
              </IconButton>
              <IconButton
                label="上一台"
                onClick={previous}
                className="h-12 w-12 border-transparent bg-transparent text-white hover:bg-white/5 sm:h-14 sm:w-14"
              >
                <SkipBack size={30} fill="currentColor" strokeWidth={1.5} />
              </IconButton>
              <button
                type="button"
                aria-label={state.isPlaying ? "暂停" : "播放"}
                onClick={togglePlayPause}
                className="neon-glow-magenta grid h-20 w-20 place-items-center rounded-full bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] text-white shadow-[0_0_34px_rgba(255,0,110,0.48)] transition active:scale-95"
              >
                {state.isPlaying ? (
                  <Pause size={30} fill="currentColor" />
                ) : (
                  <Play size={30} fill="currentColor" />
                )}
              </button>
              <IconButton
                label="下一台"
                onClick={next}
                className="h-12 w-12 border-transparent bg-transparent text-white hover:bg-white/5 sm:h-14 sm:w-14"
              >
                <SkipForward size={30} fill="currentColor" strokeWidth={1.5} />
              </IconButton>
              <IconButton
                label="查看播放列表"
                onClick={() => setIsPlaylistOpen(true)}
                className="h-11 w-11 border-transparent bg-transparent text-white/70 hover:bg-white/5 sm:h-12 sm:w-12"
              >
                <ListMusic size={26} />
              </IconButton>
            </div>

            <label className="flex w-full max-w-2xl items-center px-2 text-sm text-white/60">
              <span className="sr-only">音量</span>
              <input
                aria-label="音量"
                type="range"
                min="0"
                max="1"
                step="0.01"
                value={state.volume}
                onChange={(event) => setVolume(Number(event.target.value))}
                className="w-full accent-[var(--neon-cyan)]"
              />
            </label>
          </div>
        </div>
        {isPlaylistOpen ? (
          <StationPlaylistDialog
            title={state.playlistTitle}
            stations={currentPlaylist}
            currentStationId={currentStation.id}
            isPlaying={state.isPlaying}
            onDismiss={() => setIsPlaylistOpen(false)}
            onSelectStation={(station) => {
              playStation(station, currentPlaylist, state.playlistTitle);
              setIsPlaylistOpen(false);
            }}
          />
        ) : null}
      </div>
    </div>
  );
}

function StationPlaylistDialog({
  title,
  stations,
  currentStationId,
  isPlaying,
  onDismiss,
  onSelectStation,
}: {
  title: string;
  stations: Station[];
  currentStationId: string;
  isPlaying: boolean;
  onDismiss: () => void;
  onSelectStation: (station: Station) => void;
}) {
  const displayTitle = title.trim() || "播放列表";

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="播放列表"
      className="absolute inset-0 z-[60] flex items-end bg-black/55 text-left backdrop-blur-md sm:items-center sm:justify-center"
    >
      <div className="max-h-[78dvh] w-full overflow-hidden rounded-t-[2rem] border border-white/10 bg-[rgba(10,10,15,0.97)] shadow-[0_-18px_60px_rgba(0,0,0,0.52)] sm:max-w-lg sm:rounded-3xl sm:shadow-[0_22px_70px_rgba(0,0,0,0.56)]">
        <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <div className="min-w-0">
            <h2 className="truncate text-lg font-black text-white">
              {displayTitle}
            </h2>
            <p className="mt-1 text-xs text-white/45">
              {stations.length > 0 ? `${stations.length} 个电台` : "暂无播放列表"}
            </p>
          </div>
          <button
            type="button"
            aria-label="关闭播放列表"
            onClick={onDismiss}
            className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-white/8 text-white/70 transition hover:bg-white/12 hover:text-white"
          >
            <X size={22} />
          </button>
        </div>

        {stations.length > 0 ? (
          <div className="scrollbar-none max-h-[60dvh] space-y-2 overflow-y-auto px-3 py-3">
            {stations.map((station) => {
              const isCurrent = station.id === currentStationId;

              return (
                <button
                  key={station.id}
                  type="button"
                  aria-current={isCurrent ? "true" : undefined}
                  onClick={() => onSelectStation(station)}
                  className={`flex w-full items-center gap-3 rounded-2xl border px-3 py-3 text-left transition ${
                    isCurrent
                      ? "border-[rgba(0,217,255,0.48)] bg-[rgba(0,217,255,0.10)] text-white shadow-[0_0_20px_rgba(0,217,255,0.10)]"
                      : "border-white/8 bg-white/[0.04] text-white/75 hover:border-white/18 hover:bg-white/[0.07]"
                  }`}
                >
                  <StationAvatar
                    name={station.name}
                    stationId={station.id}
                    favicon={station.favicon}
                    sizeClassName="h-12 w-12"
                  />
                  <span className="min-w-0 flex-1">
                    <span
                      className={`block truncate text-sm font-bold ${
                        isCurrent ? "text-[var(--neon-cyan)]" : "text-white"
                      }`}
                    >
                      {station.name}
                    </span>
                    <span className="mt-1 block truncate text-xs text-white/45">
                      {station.tags || station.country || station.codec}
                    </span>
                  </span>
                  {isCurrent && isPlaying ? (
                    <span className="flex h-6 items-center gap-0.5" aria-label="正在播放">
                      {[8, 14, 10].map((height, index) => (
                        <span
                          key={`${height}-${index}`}
                          className="w-1 rounded-full bg-[var(--neon-cyan)]"
                          style={{ height }}
                        />
                      ))}
                    </span>
                  ) : null}
                </button>
              );
            })}
          </div>
        ) : (
          <div className="px-5 py-12 text-center text-white/55">
            暂无播放列表
          </div>
        )}
      </div>
    </div>
  );
}

function RecognizedSongExperience({
  result,
  recognitionStartedAt,
  stationName,
}: {
  result: RecognitionResult;
  recognitionStartedAt?: number;
  stationName: string;
}) {
  const versions = useMemo(() => result.versions ?? [], [result.versions]);
  const defaultVersionId = useMemo(
    () => findInitialVersionId(result, versions),
    [result, versions]
  );
  const [selectedVersionId, setSelectedVersionId] = useState<string | undefined>();
  const activeVersionId = versions.some((version) => version.id === selectedVersionId)
    ? selectedVersionId
    : defaultVersionId;

  const selectedVersion =
    versions.find((version) => version.id === activeVersionId) ?? versions[0];
  const activeLyrics = selectedVersion?.lyrics ?? result.lyrics;
  const primaryCandidate =
    selectedVersion?.candidate ?? activeLyrics?.matchedCandidate ?? readPrimaryCandidate(result);
  const displayCandidate = resolveDisplayCandidate(primaryCandidate, result, versions);
  const title = displayCandidate?.title || "识别结果";
  const artist = displayCandidate?.artist || "未知歌手";
  const album = displayCandidate?.album;
  const artworkUrl = displayCandidate?.artworkUrl;
  const proxiedArtworkUrl = makeArtworkProxyUrl(artworkUrl);
  const releaseDate = displayCandidate?.releaseDate;
  const [loadedArtwork, setLoadedArtwork] = useState<{
    artworkUrl: string;
    dataUrl: string;
  } | null>(null);
  const shareTimestamp = useMemo(
    () => (recognitionStartedAt ? new Date(recognitionStartedAt) : new Date()),
    [recognitionStartedAt]
  );
  const releaseMemory = formatReleaseMemory(releaseDate, shareTimestamp);
  const artworkDataUrl =
    loadedArtwork && loadedArtwork.artworkUrl === artworkUrl
      ? loadedArtwork.dataUrl
      : undefined;
  const shareCardData: ShareCardData = {
    title,
    artist,
    album,
    artworkUrl,
    artworkDataUrl,
    releaseDate,
    stationName,
    timestamp: shareTimestamp,
  };
  const [sharePreviewData, setSharePreviewData] = useState<ShareCardData | null>(
    null
  );
  const [isPreparingSharePreview, setIsPreparingSharePreview] = useState(false);
  const cacheLoadedArtwork = (image: HTMLImageElement) => {
    if (!artworkUrl) return;

    const dataUrl = readLoadedArtworkDataUrl(image);
    if (dataUrl) setLoadedArtwork({ artworkUrl, dataUrl });
  };

  const handleOpenSharePreview = async () => {
    if (isPreparingSharePreview) return;

    setIsPreparingSharePreview(true);
    try {
      setSharePreviewData(await prepareShareCardData(shareCardData));
    } catch {
      setSharePreviewData(shareCardData);
    } finally {
      setIsPreparingSharePreview(false);
    }
  };

  return (
    <div className="flex w-full max-w-3xl flex-col items-center gap-3 text-left">
      <section
        aria-label="识别结果"
        className="w-full border-y border-[rgba(131,56,236,0.55)] bg-[rgba(5,6,12,0.72)] px-4 py-2.5 shadow-[0_0_28px_rgba(131,56,236,0.16)] sm:rounded-3xl sm:border sm:py-3"
      >
        <div className="mx-auto flex max-w-xl items-center gap-3">
          {proxiedArtworkUrl ? (
            <Image
              src={proxiedArtworkUrl}
              alt={`${title}封面`}
              width={56}
              height={56}
              unoptimized
              loading="eager"
              draggable={false}
              onLoad={(event) => cacheLoadedArtwork(event.currentTarget)}
              className="h-12 w-12 shrink-0 rounded-2xl object-cover shadow-[0_0_24px_rgba(131,56,236,0.36)] ring-1 ring-white/10 sm:h-14 sm:w-14"
            />
          ) : (
            <div className="grid h-12 w-12 shrink-0 place-items-center overflow-hidden rounded-2xl bg-[linear-gradient(135deg,var(--neon-purple),var(--neon-magenta))] text-lg font-black text-white shadow-[0_0_24px_rgba(131,56,236,0.36)] sm:h-14 sm:w-14 sm:text-xl">
              {title.trim().slice(0, 1) || "音"}
            </div>
          )}
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-base font-black leading-tight text-white sm:text-lg">
              {title}
            </h2>
            <p className="mt-1 truncate text-[11px] text-white/68 sm:text-xs">
              {artist}
              {album ? ` | ${album}` : ""}
            </p>
            {releaseMemory ? (
              <p className="mt-0.5 truncate text-[10px] text-white/45 sm:text-[11px]">
                {releaseMemory}
              </p>
            ) : null}
          </div>
          <button
            type="button"
            aria-label="生成分享图"
            aria-busy={isPreparingSharePreview}
            disabled={isPreparingSharePreview}
            onClick={handleOpenSharePreview}
            className="grid h-10 w-10 shrink-0 place-items-center rounded-xl border border-[rgba(0,217,255,0.26)] bg-[rgba(0,217,255,0.10)] text-[var(--neon-cyan)] shadow-[0_0_16px_rgba(0,217,255,0.14)] transition hover:border-[rgba(0,217,255,0.5)] hover:bg-[rgba(0,217,255,0.16)] active:scale-95 disabled:cursor-wait disabled:opacity-70"
          >
            {isPreparingSharePreview ? (
              <Loader2 className="animate-spin" size={17} />
            ) : (
              <Share2 size={17} />
            )}
          </button>
        </div>
      </section>

      <VersionSelector
        versions={versions}
        selectedVersionId={selectedVersion?.id}
        onSelectVersion={setSelectedVersionId}
      />

      <MusicPlatformLinks
        result={result}
        candidate={displayCandidate}
        lyrics={activeLyrics}
      />

      {activeLyrics ? (
        <SyncedLyricsPanel
          key={`${selectedVersion?.id ?? activeLyrics.source}:${activeLyrics.rawLrc}:${recognitionStartedAt ?? 0}`}
          lyrics={activeLyrics}
          recognitionStartedAt={recognitionStartedAt}
        />
      ) : (
        <p className="w-full rounded-3xl border border-white/10 bg-black/50 px-5 py-8 text-center text-white/55">
          暂无同步歌词
        </p>
      )}

      {sharePreviewData ? (
        <ShareCardPreview
          data={sharePreviewData}
          onDismiss={() => setSharePreviewData(null)}
        />
      ) : null}
    </div>
  );
}

function ShareCardPreview({
  data,
  onDismiss,
}: {
  data: ShareCardData;
  onDismiss: () => void;
}) {
  const [isSharing, setIsSharing] = useState(false);
  const [isDownloading, setIsDownloading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [preparedPreview, setPreparedPreview] = useState<{
    input: ShareCardData;
    data: ShareCardData;
  } | null>(null);
  const preparedPreviewData =
    preparedPreview?.input === data ? preparedPreview.data : null;
  const isArtworkPreparationNeeded =
    Boolean(data.artworkUrl) &&
    !data.artworkDataUrl?.startsWith("data:image/") &&
    !data.artworkUrl?.startsWith("data:image/");
  const isArtworkPreparing =
    isArtworkPreparationNeeded && preparedPreviewData === null;
  const previewData = preparedPreviewData ?? data;
  const previewSrc = useMemo(
    () => createShareCardSvgDataUrl(previewData),
    [previewData]
  );

  useEffect(() => {
    let isCancelled = false;

    void prepareShareCardData(data).then((preparedData) => {
      if (!isCancelled) setPreparedPreview({ input: data, data: preparedData });
    });

    return () => {
      isCancelled = true;
    };
  }, [data]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onDismiss();
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onDismiss]);

  const handleShare = async () => {
    if (isArtworkPreparing || isDownloading) return;

    setIsSharing(true);
    setError(null);

    try {
      await shareOrDownloadShareCard(previewData);
      onDismiss();
    } catch (shareError) {
      if (
        shareError instanceof DOMException &&
        shareError.name === "AbortError"
      ) {
        return;
      }

      setError("分享图生成失败，请稍后再试。");
    } finally {
      setIsSharing(false);
    }
  };

  const handleDownload = async () => {
    if (isArtworkPreparing || isSharing) return;

    setIsDownloading(true);
    setError(null);

    try {
      await downloadShareCard(previewData);
    } catch {
      setError("分享图下载失败，请稍后再试。");
    } finally {
      setIsDownloading(false);
    }
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="分享图预览"
      className="fixed inset-0 z-[70] flex h-[100dvh] flex-col bg-black/80 px-8 py-5 text-center backdrop-blur-md"
    >
      <div className="flex justify-end">
        <button
          type="button"
          aria-label="关闭分享预览"
          onClick={onDismiss}
          className="grid h-10 w-10 place-items-center rounded-full text-white/80 transition hover:bg-white/10 hover:text-white"
        >
          <X size={30} />
        </button>
      </div>

      <div className="flex min-h-0 flex-1 items-center justify-center py-4">
        {isArtworkPreparing ? (
          <div
            role="status"
            className="flex w-full max-w-[360px] flex-col items-center justify-center rounded-3xl border border-white/10 bg-black/45 px-6 py-20 text-white/70 shadow-[0_18px_54px_rgba(0,0,0,0.45)]"
          >
            <Loader2 className="mb-3 animate-spin text-[var(--neon-cyan)]" size={24} />
            <span className="text-sm font-semibold">正在准备封面...</span>
          </div>
        ) : (
          <Image
            src={previewSrc}
            alt={`${data.title} - ${data.artist} 分享图预览`}
            width={360}
            height={620}
            unoptimized
            className="max-h-full w-full max-w-[360px] rounded-3xl object-contain shadow-[0_18px_54px_rgba(0,0,0,0.55)]"
          />
        )}
      </div>

      <div className="mx-auto flex w-full max-w-[360px] flex-col gap-2 pb-1">
        <div className="grid grid-cols-2 gap-2">
          <button
            type="button"
            aria-label="下载"
            disabled={isDownloading || isArtworkPreparing || isSharing}
            onClick={handleDownload}
            className="flex w-full items-center justify-center gap-2 rounded-2xl border border-white/14 bg-white/10 px-4 py-4 font-semibold text-white transition hover:bg-white/16 active:scale-[0.99] disabled:cursor-wait disabled:opacity-70"
          >
            {isDownloading ? (
              <Loader2 className="animate-spin" size={18} />
            ) : (
              <Download size={18} />
            )}
            下载
          </button>
          <button
            type="button"
            aria-label="分享"
            disabled={isSharing || isArtworkPreparing || isDownloading}
            onClick={handleShare}
            className="flex w-full items-center justify-center gap-2 rounded-2xl bg-white px-4 py-4 font-semibold text-black transition hover:bg-white/90 active:scale-[0.99] disabled:cursor-wait disabled:opacity-70"
          >
            {isSharing ? (
              <Loader2 className="animate-spin" size={18} />
            ) : (
              <Share2 size={18} />
            )}
            分享
          </button>
        </div>
        {error ? (
          <p role="alert" className="text-xs text-white/65">
            {error}
          </p>
        ) : null}
      </div>
    </div>
  );
}

function VersionSelector({
  versions,
  selectedVersionId,
  onSelectVersion,
}: {
  versions: RecognizedSongVersion[];
  selectedVersionId?: string;
  onSelectVersion: (versionId: string) => void;
}) {
  const [isExpanded, setIsExpanded] = useState(false);

  if (versions.length <= 1) return null;

  const buttonLabel = `当前版本可能不对，查看 ${versions.length} 个候选版本`;

  return (
    <div className="w-full max-w-3xl px-1">
      <button
        type="button"
        aria-label={buttonLabel}
        aria-expanded={isExpanded}
        aria-controls="song-version-options"
        onClick={() => setIsExpanded((current) => !current)}
        className="mx-auto flex items-center gap-1.5 rounded-full border border-white/10 bg-white/[0.05] px-2.5 py-1 font-normal text-white/62 transition hover:border-[rgba(0,217,255,0.42)] hover:text-[var(--neon-cyan)]"
        style={{ fontSize: 11, lineHeight: 1 }}
      >
        <span>版本不对？</span>
        <span className="text-[color:var(--neon-cyan)]">
          查看 {versions.length} 个候选
        </span>
        <ChevronDown
          size={14}
          className={`transition-transform ${isExpanded ? "rotate-180" : ""}`}
        />
      </button>

      {isExpanded ? (
        <div
          id="song-version-options"
          role="group"
          aria-label="可能版本"
          className="scrollbar-none mt-2 flex w-full gap-2 overflow-x-auto"
        >
          {versions.map((version) => {
            const isSelected = version.id === selectedVersionId;
            const album = version.candidate.album;
            const label = [version.candidate.artist, album].filter(Boolean).join(" ");

            return (
              <button
                key={version.id}
                type="button"
                aria-label={label || version.candidate.title}
                aria-pressed={isSelected}
                onClick={() => {
                  onSelectVersion(version.id);
                  setIsExpanded(false);
                }}
                className={`min-w-0 shrink-0 rounded-2xl border px-2.5 py-1.5 text-left transition ${
                  isSelected
                    ? "border-[rgba(0,217,255,0.65)] bg-[rgba(0,217,255,0.13)] text-white shadow-[0_0_18px_rgba(0,217,255,0.16)]"
                    : "border-white/10 bg-white/[0.05] text-white/58 hover:border-white/25 hover:text-white"
                }`}
              >
                <span className="block max-w-28 truncate text-[11px] font-bold sm:max-w-36">
                  {version.candidate.artist || "未知歌手"}
                </span>
                <span className="mt-0.5 block max-w-28 truncate text-[10px] text-white/45 sm:max-w-36">
                  {album || version.candidate.title}
                </span>
              </button>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}

function MusicPlatformLinks({
  result,
  candidate,
  lyrics,
}: {
  result: RecognitionResult;
  candidate?: SongCandidate;
  lyrics?: SyncedLyrics | null;
}) {
  const primaryCandidate = candidate ?? readPrimaryCandidate(result);
  const title = primaryCandidate?.title || result.transcript;
  const artist = primaryCandidate?.artist || "";
  const query = encodeURIComponent(`${title} ${artist}`.trim());
  const netEaseCandidate =
    primaryCandidate?.source === "netease"
      ? primaryCandidate
      : findMatchingNetEaseCandidate(result.candidates, primaryCandidate);
  const netEaseTargets = makeMusicPlatformTargets({
    platform: "netease",
    songId:
      netEaseCandidate?.id ??
      (primaryCandidate?.source === "qq"
        ? undefined
        : lyrics?.platformSongIds?.netease),
    title,
    artist,
  });
  const qqTargets = makeMusicPlatformTargets({
    platform: "qq",
    songId: lyrics?.platformSongIds?.qq,
    title,
    artist,
  });
  const links = [
    {
      id: "apple",
      label: "Apple Music",
      href: `https://music.apple.com/search?term=${query}`,
      fallbackHref: null,
      iconSrc: "/platform-icons/apple-music.png",
      iconAlt: "Apple Music图标",
      iconImageClassName: "h-full w-full rounded-[12px] object-cover",
    },
    netEaseTargets
      ? {
          id: "netease",
          label: "网易云音乐",
          href: netEaseTargets.primaryHref,
          fallbackHref: netEaseTargets.fallbackHref,
          iconSrc: "/platform-icons/netease-music.png",
          iconAlt: "网易云音乐图标",
          iconImageClassName:
            "h-full w-full scale-[1.18] rounded-[12px] object-cover",
        }
      : null,
    qqTargets
      ? {
          id: "qq",
          label: "QQ音乐",
          href: qqTargets.primaryHref,
          fallbackHref: qqTargets.fallbackHref,
          iconSrc: "/platform-icons/qq-music.png",
          iconAlt: "QQ音乐图标",
          iconImageClassName:
            "h-9 w-9 rounded-[11px] object-contain sm:h-10 sm:w-10",
        }
      : null,
  ].filter((link): link is NonNullable<typeof link> => Boolean(link));

  return (
    <div
      role="group"
      aria-label="音乐平台"
      className="flex items-center justify-center gap-3"
    >
      {links.map((link) => (
        <a
          key={link.id}
          href={link.href}
          data-fallback-href={link.fallbackHref ?? undefined}
          onClick={(event) => openAppPreferredLink(event, link.fallbackHref)}
          target={link.fallbackHref ? undefined : "_blank"}
          rel={link.fallbackHref ? undefined : "noreferrer"}
          aria-label={link.label}
          title={link.label}
          className="grid h-11 w-11 place-items-center overflow-hidden rounded-xl bg-white/[0.06] shadow-[0_0_18px_rgba(0,0,0,0.28)] ring-1 ring-white/10 transition hover:-translate-y-0.5 hover:scale-105 hover:ring-white/25 sm:h-12 sm:w-12"
        >
          <Image
            src={link.iconSrc}
            alt={link.iconAlt}
            width={64}
            height={64}
            loading="eager"
            draggable={false}
            className={link.iconImageClassName}
          />
        </a>
      ))}
      <span className="h-8 w-px bg-white/16 sm:h-10" aria-hidden="true" />
      <a
        href={primaryCandidate?.url ?? `https://www.google.com/search?q=${query}`}
        target="_blank"
        rel="noreferrer"
        aria-label="打开搜索结果"
        title="打开搜索结果"
        className="grid h-11 w-11 place-items-center rounded-full bg-white/10 text-white/65 transition hover:text-[var(--neon-cyan)] sm:h-12 sm:w-12"
      >
        <ExternalLink size={22} />
      </a>
    </div>
  );
}

function openAppPreferredLink(
  event: MouseEvent<HTMLAnchorElement>,
  fallbackHref: string | null
) {
  if (!fallbackHref || typeof window === "undefined") return;

  event.preventDefault();

  let fallbackTimer: number | null = null;
  const cleanup = () => {
    if (fallbackTimer) {
      window.clearTimeout(fallbackTimer);
      fallbackTimer = null;
    }
    document.removeEventListener("visibilitychange", cleanup);
    window.removeEventListener("pagehide", cleanup);
  };

  document.addEventListener("visibilitychange", cleanup, { once: true });
  window.addEventListener("pagehide", cleanup, { once: true });

  fallbackTimer = window.setTimeout(() => {
    cleanup();
    if (!document.hidden) window.location.href = fallbackHref;
  }, 1200);

  window.location.href = event.currentTarget.href;
}

function readPrimaryCandidate(result: RecognitionResult) {
  return result.lyrics?.matchedCandidate ?? result.candidates[0];
}

function resolveDisplayCandidate(
  candidate: SongCandidate | undefined,
  result: RecognitionResult,
  versions: RecognizedSongVersion[]
) {
  if (!candidate) return candidate;

  const enrichmentCandidate = findDisplayMetadataCandidate(candidate, [
    ...result.candidates,
    result.lyrics?.matchedCandidate,
    ...versions.flatMap((version) => [
      version.candidate,
      version.lyrics.matchedCandidate,
    ]),
  ]);

  if (!enrichmentCandidate) return candidate;

  return {
    ...candidate,
    album: candidate.album ?? enrichmentCandidate.album,
    artworkUrl: candidate.artworkUrl ?? enrichmentCandidate.artworkUrl,
    releaseDate: candidate.releaseDate ?? enrichmentCandidate.releaseDate,
  };
}

function findDisplayMetadataCandidate(
  target: SongCandidate,
  candidates: Array<SongCandidate | undefined>
) {
  const metadataCandidates = candidates.filter(hasDisplayMetadata);

  return (
    metadataCandidates.find(
      (candidate) =>
        candidate.source === target.source &&
        candidate.id === target.id
    ) ??
    metadataCandidates.find(
      (candidate) =>
        normalizedDisplayText(candidate.title) ===
          normalizedDisplayText(target.title) &&
        normalizedDisplayText(candidate.artist) ===
          normalizedDisplayText(target.artist) &&
        isCompatibleAlbum(candidate.album, target.album)
    )
  );
}

function hasDisplayMetadata(
  candidate: SongCandidate | undefined
): candidate is SongCandidate {
  return Boolean(candidate?.album || candidate?.artworkUrl || candidate?.releaseDate);
}

function readLoadedArtworkDataUrl(image: HTMLImageElement) {
  if (!image.complete || image.naturalWidth <= 0 || image.naturalHeight <= 0) {
    return null;
  }

  try {
    const canvas = document.createElement("canvas");
    canvas.width = image.naturalWidth;
    canvas.height = image.naturalHeight;
    const context = canvas.getContext("2d");
    if (!context) return null;

    context.drawImage(image, 0, 0);
    return canvas.toDataURL("image/png");
  } catch {
    return null;
  }
}

function findMatchingNetEaseCandidate(
  candidates: SongCandidate[],
  primaryCandidate?: SongCandidate
) {
  if (!primaryCandidate) return undefined;

  return candidates.find(
    (candidate) =>
      candidate.source === "netease" &&
      normalizedDisplayText(candidate.title) ===
        normalizedDisplayText(primaryCandidate.title) &&
      normalizedDisplayText(candidate.artist) ===
        normalizedDisplayText(primaryCandidate.artist)
  );
}

function normalizedDisplayText(text: string) {
  return text.trim().toLowerCase();
}

function isCompatibleAlbum(
  candidateAlbum: string | undefined,
  targetAlbum: string | undefined
) {
  if (!candidateAlbum || !targetAlbum) return true;
  return normalizedDisplayText(candidateAlbum) === normalizedDisplayText(targetAlbum);
}

function findInitialVersionId(
  result: RecognitionResult,
  versions: RecognizedSongVersion[]
) {
  const matchedCandidate = result.lyrics?.matchedCandidate;
  if (matchedCandidate) {
    const matchedVersion = versions.find(
      (version) =>
        version.candidate.source === matchedCandidate.source &&
        version.candidate.id === matchedCandidate.id
    );
    if (matchedVersion) return matchedVersion.id;
  }

  return versions[0]?.id;
}

function RecognitionAction({
  onRecognize,
}: {
  onRecognize: () => void;
}) {
  void onRecognize;

  return (
    <a
      href={MACOS_DOWNLOAD_URL}
      aria-label="下载 macOS 客户端使用歌曲识别"
      className="flex min-h-12 w-72 max-w-[calc(100vw-7rem)] items-center overflow-hidden rounded-full border border-[rgba(255,0,110,0.45)] bg-[rgba(25,18,35,0.72)] px-4 text-left shadow-[0_0_20px_rgba(255,0,110,0.12)] transition-colors hover:border-[rgba(255,0,110,0.75)]"
    >
      <span
        className="flex min-w-0 items-center gap-2.5"
        style={{ transform: "translateZ(0)", backfaceVisibility: "hidden" }}
      >
        <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full border border-[rgba(255,0,110,0.62)] text-[var(--neon-magenta)]">
          <Sparkles size={15} />
        </span>
        <span className="min-w-0">
          <span className="block truncate text-base font-bold leading-none text-white">
            macOS 版识曲
          </span>
          <span className="mt-1 block truncate text-[11px] text-[var(--neon-cyan)]">
            下载 macOS 客户端使用完整识曲
          </span>
        </span>
      </span>
    </a>
  );
}

function PlayerVisualizer() {
  const bars = [
    22, 34, 18, 30, 38, 24, 42, 20, 48, 28, 36, 24, 26, 30, 22, 34, 32, 24,
    46, 30, 38, 42, 50, 54, 24, 32, 42, 48, 30, 54, 18,
  ];

  return (
    <div
      aria-hidden="true"
      className="flex h-14 items-center justify-center gap-1.5 text-[var(--neon-cyan)]"
    >
      {bars.map((height, index) => (
        <span
          key={`${height}-${index}`}
          className="w-1.5 rounded-full bg-[linear-gradient(180deg,var(--neon-purple),var(--neon-cyan))] shadow-[0_0_10px_rgba(0,217,255,0.6)]"
          style={{ height: `${height}px` }}
        />
      ))}
    </div>
  );
}

function RecognitionStatusPanel({
  recognition,
}: {
  recognition: RecognitionPanelState;
}) {
  if (recognition.status === "idle" || recognition.status === "success") return null;

  if (recognition.status === "loading") {
    return (
      <div className="w-full max-w-md rounded-2xl border border-[rgba(0,217,255,0.25)] bg-[rgba(0,217,255,0.08)] px-4 py-3 text-sm text-white/75">
        <div className="flex items-center justify-center gap-2 text-[var(--neon-cyan)]">
          <Loader2 className="animate-spin" size={16} />
          正在听取歌词...
        </div>
      </div>
    );
  }

  if (recognition.status === "error") {
    return (
      <div className="w-full max-w-md rounded-2xl border border-[rgba(255,59,48,0.35)] bg-[rgba(255,59,48,0.12)] px-4 py-3 text-sm text-white/75">
        {recognition.error ?? "暂时没能识别出歌词，请稍后再试。"}
      </div>
    );
  }
  return null;
}
