"use client";

/* eslint-disable @next/next/no-img-element */

import { useMemo, useState } from "react";

type StationAvatarProps = {
  name: string;
  stationId: string;
  favicon: string;
  sizeClassName?: string;
};

const FALLBACK_GRADIENTS = [
  ["var(--neon-cyan)", "var(--neon-purple)"],
  ["var(--neon-magenta)", "var(--neon-purple)"],
  ["var(--neon-mint)", "var(--neon-cyan)"],
  ["var(--neon-gold)", "var(--neon-magenta)"],
  ["var(--neon-electric)", "var(--neon-cyan)"],
  ["var(--neon-warm-pink)", "var(--neon-purple)"],
  ["var(--neon-cyan)", "var(--neon-mint)"],
  ["var(--neon-purple)", "var(--neon-magenta)"],
  ["var(--neon-magenta)", "var(--neon-gold)"],
  ["var(--neon-electric)", "var(--neon-warm-pink)"],
] as const;

function hashStationId(stationId: string) {
  let hash = 0;

  for (const character of stationId) {
    hash = (hash * 31 + character.charCodeAt(0)) >>> 0;
  }

  return hash;
}

function getRenderableFavicon(favicon: string) {
  const trimmedFavicon = favicon.trim();

  if (!trimmedFavicon || trimmedFavicon.startsWith("bundle://")) return null;
  if (trimmedFavicon.startsWith("http://")) return null;

  return trimmedFavicon;
}

export function StationAvatar({
  name,
  stationId,
  favicon,
  sizeClassName = "h-16 w-16",
}: StationAvatarProps) {
  const [failedFavicon, setFailedFavicon] = useState<string | null>(null);
  const initial = name.trim().slice(0, 1) || "F";
  const gradient = useMemo(
    () => FALLBACK_GRADIENTS[hashStationId(stationId) % FALLBACK_GRADIENTS.length],
    [stationId],
  );
  const renderableFavicon = getRenderableFavicon(favicon);
  const shouldRenderImage = renderableFavicon && failedFavicon !== renderableFavicon;

  if (shouldRenderImage) {
    return (
      <img
        src={renderableFavicon}
        alt={name}
        loading="lazy"
        decoding="async"
        fetchPriority="low"
        className={`${sizeClassName} shrink-0 rounded-2xl bg-[var(--neon-card-bg)] object-cover`}
        onError={() => {
          setFailedFavicon(renderableFavicon);
        }}
      />
    );
  }

  return (
    <div
      data-station-id={stationId}
      className={`${sizeClassName} grid shrink-0 place-items-center rounded-2xl text-xl font-black text-white shadow-lg`}
      style={{
        backgroundImage: `linear-gradient(135deg, ${gradient[0]}, ${gradient[1]})`,
      }}
    >
      {initial}
    </div>
  );
}
