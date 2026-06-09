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
            data-label={label as string}
            onClick={() => setTab(value as Tab)}
            className={`rounded-2xl border px-3 py-3 text-sm font-bold after:mt-1 after:block after:content-[attr(data-label)] ${
              tab === value
                ? "border-[rgba(0,217,255,0.7)] bg-[rgba(0,217,255,0.16)] text-white neon-glow-cyan"
                : "border-white/10 bg-white/[0.04] text-white/55"
            }`}
          >
            <Icon className="mx-auto mb-1" size={18} />
          </button>
        ))}
      </nav>

      {tab === "home" ? (
        <section className="space-y-4">
          {topStations.isLoading ? (
            <div className="flex items-center justify-center py-12 text-[var(--neon-cyan)]">
              <Loader2 className="animate-spin" />
            </div>
          ) : topStations.error ? (
            <EmptyState
              title="暂时无法加载推荐"
              description="请稍后重试，当前播放不会受到影响。"
            />
          ) : (
            <StationGrid
              stations={topStations.data ?? []}
              currentStationId={currentStationId}
              favoriteIds={favoriteIds}
              playlistTitle="发现"
              onPlayStation={playStation}
              onToggleFavorite={toggleFavorite}
            />
          )}
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
          ) : (
            <StationGrid
              stations={searchResults.data ?? []}
              currentStationId={currentStationId}
              favoriteIds={favoriteIds}
              playlistTitle="搜索"
              onPlayStation={playStation}
              onToggleFavorite={toggleFavorite}
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
        <div className="fixed inset-0 z-[60] grid place-items-center bg-black/70 p-4 backdrop-blur-xl">
          <div
            role="dialog"
            aria-modal="true"
            aria-label="macOS 等待名单"
            className="w-full max-w-md rounded-3xl border border-[rgba(255,0,110,0.35)] bg-[rgba(21,21,32,0.96)] p-5"
          >
            <h2 className="text-2xl font-black text-white">macOS 版即将推出</h2>
            <p className="mt-2 text-sm leading-6 text-white/65">
              网页版先专心做好收音机。歌曲识别、歌词和更稳定的后台体验会优先在 macOS
              版开放。
            </p>
            <button
              type="button"
              onClick={() => setWaitlistOpen(false)}
              className="mt-4 rounded-2xl bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] px-4 py-3 font-bold text-white"
            >
              我知道了
            </button>
          </div>
        </div>
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
