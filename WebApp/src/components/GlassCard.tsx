import clsx from "clsx";
import type { ReactNode } from "react";

type GlassCardProps = {
  children: ReactNode;
  className?: string;
  active?: boolean;
};

export function GlassCard({
  children,
  className,
  active = false,
}: GlassCardProps) {
  return (
    <div
      className={clsx(
        "min-w-0 max-w-full rounded-2xl border bg-[rgba(21,21,32,0.72)] backdrop-blur-xl",
        active
          ? "border-[rgba(0,217,255,0.72)] neon-glow-cyan"
          : "border-[rgba(255,255,255,0.12)]",
        className,
      )}
    >
      {children}
    </div>
  );
}
