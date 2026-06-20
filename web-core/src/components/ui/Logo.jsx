export default function Logo({
  size = 44,
  wordmark = true,
  variant = 'dark',
  subtitle = 'CORE FINANCIERO',
}) {
  const light = variant === 'light'
  const textColor = light ? '#ffffff' : '#007a3d'
  const subColor = light ? 'rgba(255,255,255,.84)' : '#59665f'
  const nameSize = Math.round(size * 0.47)
  const subSize = Math.max(9, Math.round(size * 0.21))

  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 12 }}>
      <svg
        width={size}
        height={size}
        viewBox="0 0 48 48"
        xmlns="http://www.w3.org/2000/svg"
        aria-label="Banco Falabella"
        role="img"
      >
        <defs>
          <linearGradient id="bfMark" x1="7" y1="40" x2="42" y2="7" gradientUnits="userSpaceOnUse">
            <stop stopColor="#004F2A" />
            <stop offset="0.62" stopColor="#007A3D" />
            <stop offset="1" stopColor="#C7D900" />
          </linearGradient>
        </defs>
        <rect x="4" y="4" width="40" height="40" rx="14" fill={light ? 'rgba(255,255,255,.16)' : '#F1F8ED'} />
        <path
          d="M15.3 30.8c8.8-1.3 15.6-6.7 18.8-15.6 1.4 7.1-1.5 15-7.6 19.6-4.9 3.7-10.9 4.4-15.1 1.9 1.1-2.6 2.3-4.6 3.9-5.9Z"
          fill="url(#bfMark)"
        />
        <path
          d="M15.8 28.2c4.2-6.7 10.2-10.4 18-11.2-5 4.1-9.5 8.8-13.1 15.8-1.9-.8-3.5-2.2-4.9-4.6Z"
          fill="#C7D900"
          opacity=".95"
        />
      </svg>

      {wordmark && (
        <span style={{ display: 'flex', flexDirection: 'column', lineHeight: 1.02 }}>
          <span style={{ fontWeight: 900, fontSize: nameSize, color: textColor, letterSpacing: '-.03em' }}>
            Banco Falabella
          </span>
          {subtitle && (
            <span style={{ fontSize: subSize, fontWeight: 800, color: subColor, letterSpacing: '1.3px' }}>
              {subtitle}
            </span>
          )}
        </span>
      )}
    </span>
  )
}
