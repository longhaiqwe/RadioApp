"use client";

import { Mail, Sparkles, X } from "lucide-react";
import { useEffect, useState, type FormEvent } from "react";
import type { WaitlistSource } from "@/features/waitlist/waitlistSchema";
import {
  isValidWaitlistEmail,
  normalizeWaitlistEmail,
} from "@/features/waitlist/waitlistSchema";
import { GlassCard } from "./GlassCard";
import { IconButton } from "./IconButton";

const WAITLIST_STORAGE_KEY = "radioapp:web:waitlist-email";
const WAITLIST_SAVE_ERROR = "暂时无法加入等待名单，请稍后再试。";
const WAITLIST_EMAIL_ERROR = "请输入有效邮箱地址。";

type WaitlistModalProps = {
  source: WaitlistSource;
  stationId?: string | null;
  stationName?: string | null;
  onClose: () => void;
};

type SubmissionState =
  | { kind: "idle" }
  | { kind: "submitting" }
  | { kind: "success" }
  | { kind: "duplicate" }
  | { kind: "error"; message: string };

function readSavedWaitlistEmail(): string {
  if (typeof window === "undefined") {
    return "";
  }

  return normalizeWaitlistEmail(window.localStorage.getItem(WAITLIST_STORAGE_KEY));
}

function saveWaitlistEmail(email: string) {
  if (typeof window === "undefined") {
    return;
  }

  window.localStorage.setItem(WAITLIST_STORAGE_KEY, email);
}

export function WaitlistModal({
  source,
  stationId = null,
  stationName = null,
  onClose,
}: WaitlistModalProps) {
  const [email, setEmail] = useState(readSavedWaitlistEmail);
  const [state, setState] = useState<SubmissionState>({ kind: "idle" });

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [onClose]);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    const normalizedEmail = normalizeWaitlistEmail(email);

    if (!isValidWaitlistEmail(normalizedEmail)) {
      setState({ kind: "error", message: WAITLIST_EMAIL_ERROR });
      return;
    }

    setState({ kind: "submitting" });
    const previousEmail = readSavedWaitlistEmail();

    try {
      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email: normalizedEmail,
          source,
          stationId,
          userAgent:
            typeof window === "undefined" ? null : window.navigator.userAgent,
        }),
      });
      const payload = (await response.json().catch(() => null)) as
        | { ok?: boolean; error?: string }
        | null;

      if (!response.ok || payload?.ok !== true) {
        setState({
          kind: "error",
          message:
            typeof payload?.error === "string"
              ? payload.error
              : WAITLIST_SAVE_ERROR,
        });
        return;
      }

      saveWaitlistEmail(normalizedEmail);
      setState({
        kind: previousEmail === normalizedEmail ? "duplicate" : "success",
      });
    } catch {
      setState({
        kind: "error",
        message: "网络连接有点不稳，请稍后再试。",
      });
    }
  };

  const isComplete = state.kind === "success" || state.kind === "duplicate";

  return (
    <div
      className="fixed inset-0 z-[60] grid place-items-center bg-black/70 p-4 backdrop-blur-xl"
      onClick={(event) => {
        if (event.target === event.currentTarget) {
          onClose();
        }
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="waitlist-title"
        className="w-full max-w-md"
      >
        <GlassCard
          className="rounded-[28px] border-[rgba(255,0,110,0.3)] bg-[rgba(15,16,24,0.96)] p-5 md:p-6"
          active={state.kind === "submitting"}
        >
          <div className="flex items-start gap-3">
            <div className="grid h-12 w-12 place-items-center rounded-2xl bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] text-white neon-glow-magenta">
              <Sparkles size={22} />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-semibold text-[var(--neon-cyan)]">
                macOS 抢先提醒
              </p>
              <h2 id="waitlist-title" className="mt-1 text-2xl font-black text-white">
                歌曲识别会先到 macOS 版
              </h2>
            </div>
            <IconButton label="关闭等待名单" onClick={onClose}>
              <X size={18} />
            </IconButton>
          </div>

          <p className="mt-4 text-sm leading-6 text-white/70">
            网页版先把收音机体验做到顺手。识别歌曲、歌词和更稳定的后台收听，会优先在
            macOS 版开放。
          </p>

          {stationName ? (
            <p className="mt-3 text-xs text-white/45">当前电台：{stationName}</p>
          ) : null}

          {isComplete ? (
            <div className="mt-5 space-y-4">
              <div className="rounded-3xl border border-[rgba(0,245,212,0.28)] bg-[rgba(0,245,212,0.08)] p-4">
                <p className="text-base font-bold text-white">
                  {state.kind === "duplicate"
                    ? "这个邮箱已经在名单里了"
                    : "已经帮你排上了"}
                </p>
                <p className="mt-2 text-sm leading-6 text-white/70">
                  {state.kind === "duplicate"
                    ? "我们已经记住你了，macOS 版开放时会照样通知你。"
                    : "我们会优先通知你 macOS 版开放，也会顺手告诉你识别能力什么时候上线。"}
                </p>
              </div>
              <button
                type="button"
                onClick={onClose}
                className="w-full rounded-2xl bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] px-4 py-3 font-bold text-white neon-glow-magenta"
              >
                继续听电台
              </button>
            </div>
          ) : (
            <form className="mt-5 space-y-4" onSubmit={handleSubmit} noValidate>
              <label className="block">
                <span className="mb-2 flex items-center gap-2 text-sm font-medium text-white/80">
                  <Mail size={16} className="text-[var(--neon-cyan)]" />
                  邮箱地址
                </span>
                <input
                  type="email"
                  inputMode="email"
                  autoComplete="email"
                  value={email}
                  onChange={(event) => {
                    setEmail(event.target.value);
                    if (state.kind === "error") {
                      setState({ kind: "idle" });
                    }
                  }}
                  placeholder="you@example.com"
                  aria-invalid={state.kind === "error"}
                  className="w-full rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-3 text-white outline-none transition placeholder:text-white/30 focus:border-[rgba(0,217,255,0.45)] focus:ring-2 focus:ring-[rgba(0,217,255,0.18)]"
                />
              </label>

              {state.kind === "error" ? (
                <p className="rounded-2xl border border-[rgba(255,59,48,0.28)] bg-[rgba(255,59,48,0.12)] px-3 py-2 text-sm text-white/85">
                  {state.message}
                </p>
              ) : null}

              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={onClose}
                  className="flex-1 rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-3 font-semibold text-white/70"
                >
                  稍后再说
                </button>
                <button
                  type="submit"
                  disabled={state.kind === "submitting"}
                  className="flex-1 rounded-2xl bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] px-4 py-3 font-bold text-white neon-glow-magenta disabled:cursor-not-allowed disabled:opacity-70"
                >
                  {state.kind === "submitting" ? "提交中..." : "加入等待名单"}
                </button>
              </div>
            </form>
          )}
        </GlassCard>
      </div>
    </div>
  );
}
