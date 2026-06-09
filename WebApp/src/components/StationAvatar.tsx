/* eslint-disable @next/next/no-img-element */

type StationAvatarProps = {
  name: string;
  stationId: string;
  favicon: string;
  sizeClassName?: string;
};

export function StationAvatar({
  name,
  stationId,
  favicon,
  sizeClassName = "h-16 w-16",
}: StationAvatarProps) {
  const initial = name.trim().slice(0, 1) || "F";

  if (favicon && !favicon.startsWith("bundle://")) {
    return (
      <img
        src={favicon}
        alt={name}
        className={`${sizeClassName} rounded-2xl object-cover bg-[var(--neon-card-bg)]`}
      />
    );
  }

  return (
    <div
      data-station-id={stationId}
      className={`${sizeClassName} grid place-items-center rounded-2xl bg-[linear-gradient(135deg,var(--neon-cyan),var(--neon-purple),var(--neon-magenta))] text-xl font-black text-white shadow-lg`}
    >
      {initial}
    </div>
  );
}
