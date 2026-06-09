import clsx from "clsx";
import type { ButtonHTMLAttributes, ReactNode } from "react";

type IconButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  label: string;
  active?: boolean;
  children: ReactNode;
};

export function IconButton({
  label,
  active = false,
  children,
  className,
  ...props
}: IconButtonProps) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={clsx(
        "grid h-11 w-11 place-items-center rounded-full border transition active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--neon-cyan)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--neon-dark-bg)]",
        active
          ? "border-[rgba(0,217,255,0.7)] bg-[rgba(0,217,255,0.16)] text-[var(--neon-cyan)] neon-glow-cyan"
          : "border-[rgba(255,255,255,0.12)] bg-white/10 text-white/75 hover:text-[var(--neon-cyan)]",
        className,
      )}
      {...props}
    >
      {children}
    </button>
  );
}
