"use client";

import {
  Clock3,
  Heart,
  History,
  Loader2,
  Radio,
  Search,
  Shuffle,
  Sparkles,
} from "lucide-react";
import { useMemo, useState } from "react";
import { AnimatedMeshBackground } from "@/components/AnimatedMeshBackground";
import { EmptyState } from "@/components/EmptyState";
import { GlassCard } from "@/components/GlassCard";
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

type Tab = "home" | "search" | "favorites" | "recent";

function WebRadioExperience() {
  const [tab, setTab] = useState<Tab>("home");
  const [query, setQuery] = useState("");
  const [waitlistOpen, setWaitlistOpen] = useState(false);
  const favorites = useLocalStations("radioapp:web:favorites", 100);
  const recent = useLocalStations("radioapp:web:recent", 30);
  const topStations = useTopStations();
  const searchResults = useStationSearch(query);
  const player = useAudioPlayer();
  const favoritePreview = favorites.stations.slice(0, 3);

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
    <main className="mx-auto flex min-h-screen w-full max-w-6xl flex-col px-4 pb-28 pt-12 md:px-8">
      <header className="mb-6 flex items-start gap-3">
        <div>
          <h1 className="text-5xl font-black tracking-normal text-white">发现</h1>
          <p className="mt-2 text-base font-medium text-[var(--neon-cyan)]">
            探索全球电台
          </p>
        </div>
        <button
          type="button"
          onClick={playRandom}
          className="ml-auto grid h-12 w-12 place-items-center rounded-full bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] text-white neon-glow-magenta active:scale-95"
          aria-label="随便听听"
        >
          <Shuffle size={20} />
        </button>
      </header>

      <GlassCard className="mb-4 p-3">
        <label className="flex items-center gap-3">
          <Search className="text-[var(--neon-cyan)]" size={20} />
          <input
            value={query}
            onChange={(event) => {
              setQuery(event.target.value);
              setTab("search");
            }}
            placeholder="搜索电台、风格、地区..."
            className="min-w-0 flex-1 bg-transparent py-2 text-white outline-none placeholder:text-white/40"
          />
          <Sparkles className="text-[var(--neon-purple)]" size={18} />
        </label>
      </GlassCard>

      <nav className="mb-6 grid grid-cols-4 gap-2">
        {[
          ["home", "发现", Radio],
          ["search", "搜索", Search],
          ["favorites", "收藏", Heart],
          ["recent", "最近", History],
        ].map(([value, label, Icon]) => (
          <button
            key={value as string}
            type="button"
            aria-label={label as string}
            onClick={() => setTab(value as Tab)}
            className={`rounded-2xl border px-3 py-3 text-sm font-bold ${
              tab === value
                ? "border-[rgba(0,217,255,0.7)] bg-[rgba(0,217,255,0.16)] text-white neon-glow-cyan"
                : "border-white/10 bg-white/[0.04] text-white/55"
            }`}
          >
            <Icon className="mx-auto mb-1" size={18} />
            <span className="mt-1 block">{label as string}</span>
          </button>
        ))}
      </nav>

      {tab === "home" ? (
        <section className="space-y-4">
          {favoritePreview.length > 0 ? (
            <div className="space-y-3">
              <div className="flex items-end justify-between gap-3">
                <div>
                  <h2 className="text-xl font-black text-white">你的收藏</h2>
                  <p className="mt-1 text-sm text-white/55">
                    下次回来，不用重新找。
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setTab("favorites")}
                  className="text-sm font-semibold text-[var(--neon-cyan)]"
                >
                  查看全部
                </button>
              </div>
              <StationGrid
                stations={favoritePreview}
                currentStationId={currentStationId}
                favoriteIds={favoriteIds}
                playlistTitle="收藏"
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
            {topStations.isLoading ? (
              <div className="flex items-center justify-center py-12 text-[var(--neon-cyan)]">
                <Loader2 className="animate-spin" />
              </div>
            ) : topStations.error ? (
              <EmptyState
                title="暂时无法加载推荐"
                description="请稍后重试，当前播放不会受到影响。"
              />
            ) : (topStations.data ?? []).length > 0 ? (
              <StationGrid
                stations={topStations.data ?? []}
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
      ) : null}

      {tab === "search" ? (
        <section>
          {query.trim().length === 0 ? (
            <EmptyState
              title="输入关键词开始搜索"
              description="可以搜索电台名、风格、地区或频率。"
            />
          ) : searchResults.isLoading ? (
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
      ) : null}

      {tab === "favorites" ? (
        favorites.stations.length === 0 ? (
          <EmptyState
            title="还没有收藏"
            description="在发现或搜索里点亮心形，就能把电台留在这里。"
          />
        ) : (
          <StationGrid
            stations={favorites.stations}
            currentStationId={currentStationId}
            favoriteIds={favoriteIds}
            playlistTitle="收藏"
            onPlayStation={playStation}
            onToggleFavorite={toggleFavorite}
          />
        )
      ) : null}

      {tab === "recent" ? (
        recent.stations.length === 0 ? (
          <EmptyState
            title="最近播放为空"
            description="听过的电台会自动出现在这里。"
          />
        ) : (
          <StationGrid
            stations={recent.stations}
            currentStationId={currentStationId}
            favoriteIds={favoriteIds}
            playlistTitle="最近播放"
            onPlayStation={playStation}
            onToggleFavorite={toggleFavorite}
          />
        )
      ) : null}

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

export default function Home() {
  const recent = useLocalStations("radioapp:web:recent", 30);

  return (
    <>
      <AnimatedMeshBackground />
      <AudioPlayerProvider onPlayedStation={recent.addStation}>
        <WebRadioExperience />
      </AudioPlayerProvider>
    </>
  );
}
