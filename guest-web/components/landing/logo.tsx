// The Tawla mark (lib/widgets/tawla_mark.dart): three QR corners and a coffee cup seen from above.
// It follows the text colour; the cup's centre is always terracotta. The cup spins now and then.

interface MarkProps {
  size?: number;
  spin?: boolean;
  className?: string;
}

export function LandingMark({ size = 28, spin = false, className = "" }: MarkProps) {
  return (
    <svg
      viewBox="0 0 120 120"
      width={size}
      height={size}
      aria-hidden="true"
      focusable="false"
      className={className}
      fill="none"
      stroke="currentColor"
      strokeWidth={size < 24 ? 12 : 9}
      strokeLinecap="round"
    >
      {size < 24 ? (
        <>
          <rect x="8" y="8" width="36" height="36" rx="10" />
          <rect x="76" y="8" width="36" height="36" rx="10" />
          <rect x="8" y="76" width="36" height="36" rx="10" />
          <circle cx="90" cy="90" r="16" fill="#BA5333" stroke="none" />
        </>
      ) : (
        <>
          <rect x="8" y="8" width="36" height="36" rx="10" />
          <rect x="76" y="8" width="36" height="36" rx="10" />
          <rect x="8" y="76" width="36" height="36" rx="10" />
          <g fill="currentColor" stroke="none">
            <rect x="19" y="19" width="14" height="14" rx="4" />
            <rect x="87" y="19" width="14" height="14" rx="4" />
            <rect x="19" y="87" width="14" height="14" rx="4" />
            <rect x="55" y="55" width="10" height="10" rx="3" />
          </g>
          <g className={spin ? "lp-cup" : undefined}>
            <circle cx="90" cy="90" r="17" />
            <circle cx="90" cy="90" r="8" fill="#BA5333" stroke="none" />
            <line x1="103" y1="103" x2="110" y2="110" />
          </g>
        </>
      )}
    </svg>
  );
}

interface LockupProps {
  size?: number;
  spin?: boolean;
  className?: string;
}

export function LandingLockup({ size = 30, spin = false, className = "" }: LockupProps) {
  return (
    <span dir="ltr" className={`lp-lockup ${className}`}>
      <LandingMark size={size} spin={spin} />
      <span aria-hidden="true" style={{ fontSize: size * 0.67 }}>
        Tawla
      </span>
    </span>
  );
}
