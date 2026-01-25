import { useEffect } from 'react';
import { Box, Typography } from '@mui/material';

/* ------------------------------------------------------------------ */
/*  Animated success overlay with auto-redirect                        */
/*  Props:                                                             */
/*    title    – heading text  (default "Application Submitted!")       */
/*    message  – sub-text                                              */
/*    onComplete – called after the animation finishes (~4 s)          */
/* ------------------------------------------------------------------ */
export default function SuccessOverlay({
  title = 'Application Submitted!',
  message = 'We will review your application and get back to you shortly.',
  onComplete,
}) {
  useEffect(() => {
    const timer = setTimeout(onComplete, 4000);
    return () => clearTimeout(timer);
  }, [onComplete]);

  return (
    <>
      <style>{`
        @keyframes successFadeIn {
          from { opacity: 0; }
          to   { opacity: 1; }
        }
        @keyframes successScaleIn {
          from { opacity: 0; transform: scale(0.75) translateY(24px); }
          to   { opacity: 1; transform: scale(1) translateY(0); }
        }
        @keyframes drawCircle {
          to { stroke-dashoffset: 0; }
        }
        @keyframes drawCheck {
          to { stroke-dashoffset: 0; }
        }
        @keyframes progressFill {
          from { width: 0%; }
          to   { width: 100%; }
        }
        @keyframes shimmer {
          0%   { background-position: -200% 0; }
          100% { background-position: 200% 0; }
        }
      `}</style>

      <Box
        sx={{
          position: 'fixed',
          top: 0, left: 0, right: 0, bottom: 0,
          zIndex: 9999,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'column',
          bgcolor: 'rgba(13, 71, 161, 0.92)',
          backdropFilter: 'blur(12px)',
          animation: 'successFadeIn 0.4s ease-out',
        }}
      >
        {/* Main content */}
        <Box
          sx={{
            textAlign: 'center',
            animation: 'successScaleIn 0.6s cubic-bezier(0.34, 1.56, 0.64, 1) 0.15s both',
          }}
        >
          {/* Checkmark circle */}
          <Box sx={{ mb: 3, display: 'inline-block', position: 'relative' }}>
            {/* Glow ring */}
            <Box
              sx={{
                position: 'absolute',
                inset: -12,
                borderRadius: '50%',
                border: '2px solid rgba(66, 165, 245, 0.25)',
                animation: 'successFadeIn 1s ease-out 1.2s both',
              }}
            />
            <svg width="110" height="110" viewBox="0 0 110 110">
              <circle
                cx="55" cy="55" r="48"
                fill="none"
                stroke="rgba(255,255,255,0.15)"
                strokeWidth="3"
              />
              <circle
                cx="55" cy="55" r="48"
                fill="none"
                stroke="#42A5F5"
                strokeWidth="3.5"
                strokeLinecap="round"
                style={{
                  strokeDasharray: 301.6,
                  strokeDashoffset: 301.6,
                  animation: 'drawCircle 0.8s ease-out 0.4s forwards',
                }}
              />
              <path
                d="M34 57 L48 71 L76 43"
                fill="none"
                stroke="#fff"
                strokeWidth="4.5"
                strokeLinecap="round"
                strokeLinejoin="round"
                style={{
                  strokeDasharray: 75,
                  strokeDashoffset: 75,
                  animation: 'drawCheck 0.45s ease-out 1.1s forwards',
                }}
              />
            </svg>
          </Box>

          {/* Text */}
          <Typography
            variant="h5"
            sx={{
              color: '#fff',
              fontWeight: 700,
              mb: 1,
              fontSize: { xs: '1.3rem', md: '1.5rem' },
              letterSpacing: '-0.01em',
            }}
          >
            {title}
          </Typography>
          <Typography
            sx={{
              color: 'rgba(255,255,255,0.7)',
              fontSize: { xs: '0.875rem', md: '0.95rem' },
              mb: 4,
              maxWidth: 340,
              mx: 'auto',
              lineHeight: 1.6,
            }}
          >
            {message}
          </Typography>

          {/* Progress bar */}
          <Box
            sx={{
              width: 180,
              height: 3,
              bgcolor: 'rgba(255,255,255,0.12)',
              borderRadius: 2,
              mx: 'auto',
              overflow: 'hidden',
            }}
          >
            <Box
              sx={{
                height: '100%',
                borderRadius: 2,
                background: 'linear-gradient(90deg, #42A5F5, #90CAF9, #42A5F5)',
                backgroundSize: '200% 100%',
                animation: 'progressFill 3.5s linear 0.5s forwards, shimmer 1.5s linear infinite',
              }}
            />
          </Box>
          <Typography
            variant="caption"
            sx={{
              color: 'rgba(255,255,255,0.45)',
              mt: 1.5,
              display: 'block',
              fontSize: '0.75rem',
            }}
          >
            Redirecting to home&hellip;
          </Typography>
        </Box>
      </Box>
    </>
  );
}
