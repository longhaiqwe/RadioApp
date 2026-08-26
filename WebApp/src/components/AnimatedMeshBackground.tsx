export function AnimatedMeshBackground() {
  return (
    <div
      aria-hidden="true"
      className="fixed inset-0 -z-10 overflow-hidden bg-[var(--neon-dark-bg)]"
    >
      <div className="absolute -left-36 -top-48 h-[34rem] w-[34rem] rounded-full bg-[radial-gradient(circle,var(--neon-purple)_0%,transparent_62%)] opacity-40 blur-3xl" />
      <div className="absolute -bottom-44 right-[-8rem] h-[32rem] w-[32rem] rounded-full bg-[radial-gradient(circle,var(--neon-cyan)_0%,transparent_62%)] opacity-30 blur-3xl" />
      <div className="absolute right-10 top-24 h-80 w-80 rounded-full bg-[radial-gradient(circle,var(--neon-magenta)_0%,transparent_62%)] opacity-20 blur-3xl" />
      <div className="absolute inset-0 opacity-[0.03] [background-image:radial-gradient(circle,white_1px,transparent_1px)] [background-size:18px_18px]" />
    </div>
  );
}
