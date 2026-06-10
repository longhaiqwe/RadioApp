"use client";

import {
  Clock3,
  Loader2,
  Search,
  Shuffle,
  Sparkles,
} from "lucide-react";
import { useMemo, useState } from "react";
import { AnimatedMeshBackground } from "@/components/AnimatedMeshBackground";
import { EmptyState } from "@/components/EmptyState";
import { GlassCard } from "@/components/GlassCard";
import { IconButton } from "@/components/IconButton";
import { MiniPlayer } from "@/components/MiniPlayer";
import { PlayerPanel } from "@/components/PlayerPanel";
import { StationGrid } from "@/components/StationGrid";
import { WaitlistModal } from "@/components/WaitlistModal";
import {
  AudioPlayerProvider,
  useAudioPlayer,
} from "@/features/player/AudioPlayerProvider";
import type { Station } from "@/features/stations/stationTypes";
import { useLocalStations } from "@/hooks/useLocalStations";
import { useStationSearch, useTopStations } from "@/hooks/useStations";
import { getRandomStation } from "@/lib/stationApi";

type HomeClientProps = {
  initialTopStations: Station[];
};

function WebRadioExperience({ initialTopStations }: HomeClientProps) {
  const [query, setQuery] = useState("");
  const [waitlistOpen, setWaitlistOpen] = useState(false);
  const [recentOpen, setRecentOpen] = useState(false);
  const favorites = useLocalStations("radioapp:web:favorites", 100);
  const recent = useLocalStations("radioapp:web:recent", 30);
  const topStations = useTopStations(initialTopStations);
  const searchResults = useStationSearch(query);
  const player = useAudioPlayer();
  const normalizedQuery = query.trim();
  const isSearching = normalizedQuery.length > 0;
  const topStationList = topStations.data ?? initialTopStations;
  const hasRecentStations = recent.stations.length > 0;
  const showRecentPanel = !isSearching && recentOpen && hasRecentStations;

  const favoriteIds = useMemo(
    () => new Set(favorites.stations.map((station) => station.id)),
    [favorites.stations]
  );

  const playStation = (
    station: Station,
    playlist: Station[],
    playlistTitle: string
  ) => {
    player.playStation(station, playlist, playlistTitle);
  };

  const toggleFavorite = (station: Station) => {
    if (favorites.hasStation(station.id)) favorites.removeStation(station.id);
    else favorites.addStation(station);
  };

  const playRandom = async () => {
    const station = await getRandomStation(player.state.currentStation?.id);
    if (station) playStation(station, [station], "随便听听");
  };

  const currentStationId = player.state.currentStation?.id;

  return (
    <main className="mx-auto flex min-h-screen w-full min-w-0 max-w-6xl flex-col px-4 pb-28 pt-12 md:px-8">
      <header className="mb-6 flex items-start gap-3">
        <div className="min-w-0">
          <h1 className="text-5xl font-black tracking-normal text-white">发现</h1>
          <p className="mt-2 text-base font-medium text-[var(--neon-cyan)]">
            探索全球电台
          </p>
        </div>
        <div className="ml-auto flex shrink-0 items-center gap-3">
          {hasRecentStations ? (
            <IconButton
              label={recentOpen ? "收起最近听过" : "查看最近听过"}
              active={recentOpen}
              aria-expanded={recentOpen}
              aria-controls="recent-stations-panel"
              onClick={() => setRecentOpen((isOpen) => !isOpen)}
            >
              <Clock3 size={20} />
            </IconButton>
          ) : null}
          <button
            type="button"
            onClick={playRandom}
            className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] text-white neon-glow-magenta active:scale-95"
            aria-label="随便听听"
          >
            <Shuffle size={20} />
          </button>
        </div>
      </header>

      <GlassCard className="mb-4 p-3">
        <label className="flex items-center gap-3">
          <Search className="text-[var(--neon-cyan)]" size={20} />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="搜索电台、风格、地区..."
            className="min-w-0 flex-1 bg-transparent py-2 text-white outline-none placeholder:text-white/40"
          />
          <Sparkles className="text-[var(--neon-purple)]" size={18} />
        </label>
      </GlassCard>

      {isSearching ? (
        <section className="space-y-3">
          <div>
            <h2 className="text-xl font-black text-white">搜索结果</h2>
            <p className="mt-1 text-sm text-white/55">“{normalizedQuery}”</p>
          </div>
          {searchResults.isLoading ? (
            <div className="flex items-center justify-center py-12 text-[var(--neon-cyan)]">
              <Loader2 className="animate-spin" />
            </div>
          ) : searchResults.error ? (
            <EmptyState title="搜索暂时失败" description="请保留关键词稍后重试。" />
          ) : (searchResults.data ?? []).length > 0 ? (
            <StationGrid
              stations={searchResults.data ?? []}
              currentStationId={currentStationId}
              favoriteIds={favoriteIds}
              playlistTitle="搜索"
              onPlayStation={playStation}
              onToggleFavorite={toggleFavorite}
            />
          ) : (
            <EmptyState
              title="还没有找到匹配电台"
              description="换个关键词，或者试试地区和频率。"
            />
          )}
        </section>
      ) : (
        <section className="space-y-8">
          {favorites.stations.length > 0 ? (
            <div className="space-y-3">
              <div>
                <h2 className="text-xl font-black text-white">你的收藏</h2>
                <p className="mt-1 text-sm text-white/55">
                  下次回来，不用重新找。
                </p>
              </div>
              <StationGrid
                stations={favorites.stations}
                currentStationId={currentStationId}
                favoriteIds={favoriteIds}
                playlistTitle="收藏"
                onPlayStation={playStation}
                onToggleFavorite={toggleFavorite}
              />
            </div>
          ) : null}

          {showRecentPanel ? (
            <div id="recent-stations-panel" className="space-y-3">
              <div>
                <h2 className="text-xl font-black text-white">最近听过</h2>
                <p className="mt-1 text-sm text-white/55">
                  刚刚路过的好声音，会先留在这里。
                </p>
              </div>
              <StationGrid
                stations={recent.stations}
                currentStationId={currentStationId}
                favoriteIds={favoriteIds}
                playlistTitle="最近播放"
                onPlayStation={playStation}
                onToggleFavorite={toggleFavorite}
              />
            </div>
          ) : null}

          <div className="space-y-3">
            <div>
              <h2 className="text-xl font-black text-white">推荐电台</h2>
              <p className="mt-1 text-sm text-white/55">先从熟悉又稳定的台开始。</p>
            </div>
            {topStations.isLoading && topStationList.length === 0 ? (
              <div className="flex items-center justify-center py-12 text-[var(--neon-cyan)]">
                <Loader2 className="animate-spin" />
              </div>
            ) : topStations.error ? (
              <EmptyState
                title="暂时无法加载推荐"
                description="请稍后重试，当前播放不会受到影响。"
              />
            ) : topStationList.length > 0 ? (
              <StationGrid
                stations={topStationList}
                currentStationId={currentStationId}
                favoriteIds={favoriteIds}
                playlistTitle="发现"
                onPlayStation={playStation}
                onToggleFavorite={toggleFavorite}
              />
            ) : (
              <EmptyState
                title="暂时还没有推荐电台"
                description="可以先试试搜索，或者点一下随便听听。"
              />
            )}
          </div>
        </section>
      )}

      <button
        type="button"
        onClick={() => setWaitlistOpen(true)}
        className="mt-8 inline-flex items-center justify-center gap-2 rounded-2xl border border-[rgba(255,0,110,0.3)] bg-[rgba(255,0,110,0.1)] px-4 py-3 text-sm font-bold text-white/85"
      >
        <Clock3 size={18} />
        识别歌曲：macOS 版即将推出
      </button>

      <MiniPlayer />
      <PlayerPanel
        isFavorite={
          player.state.currentStation
            ? favorites.hasStation(player.state.currentStation.id)
            : false
        }
        onToggleFavorite={toggleFavorite}
        onOpenWaitlist={() => setWaitlistOpen(true)}
      />
      {waitlistOpen ? (
        <WaitlistModal
          source="recognition"
          stationId={player.state.currentStation?.id}
          stationName={player.state.currentStation?.name}
          onClose={() => setWaitlistOpen(false)}
        />
      ) : null}
    </main>
  );
}

export function HomeClient({ initialTopStations }: HomeClientProps) {
  const recent = useLocalStations("radioapp:web:recent", 30);

  return (
    <>
      <AnimatedMeshBackground />
      <AudioPlayerProvider onPlayedStation={recent.addStation}>
        <WebRadioExperience initialTopStations={initialTopStations} />
      </AudioPlayerProvider>
    </>
  );
}
