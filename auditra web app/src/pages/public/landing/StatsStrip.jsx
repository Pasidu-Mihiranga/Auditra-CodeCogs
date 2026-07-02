import { useState, useEffect, useRef } from 'react';
import { Box, Container, Grid, Typography } from '@mui/material';
import axiosClient from '../../../api/axiosClient';

// Fallback values used until live stats load (or if the request fails).
const DEFAULT_STATS = [
    { key: 'projects_completed', target: 0, suffix: '+', label: 'Projects Completed' },
    { key: 'years_experience', target: 0, suffix: '+', label: 'Years of Experience' },
    { key: 'professionals', target: 0, suffix: '+', label: 'Professionals' },
];

function useCountUp(target, started, duration = 2000) {
    const [count, setCount] = useState(0);

    useEffect(() => {
        if (!started) return;
        let startTime = null;
        let raf;

        const step = (timestamp) => {
            if (!startTime) startTime = timestamp;
            const progress = Math.min((timestamp - startTime) / duration, 1);
            // ease-out curve
            const eased = 1 - Math.pow(1 - progress, 3);
            setCount(Math.floor(eased * target));
            if (progress < 1) {
                raf = requestAnimationFrame(step);
            }
        };

        raf = requestAnimationFrame(step);
        return () => cancelAnimationFrame(raf);
    }, [started, target, duration]);

    return count;
}

function StatItem({ target, suffix, label, started }) {
    const count = useCountUp(target, started);

    return (
        <Box sx={{ textAlign: 'center', py: { xs: 2, md: 3 } }}>
            <Typography
                variant="h3"
                sx={{
                    fontWeight: 800,
                    color: '#1565C0',
                    fontSize: { xs: '2rem', md: '2.8rem' },
                    lineHeight: 1,
                    mb: 0.5,
                }}
            >
                {started ? count : 0}{suffix}
            </Typography>
            <Typography
                variant="body2"
                sx={{
                    color: '#64748B',
                    fontWeight: 500,
                    fontSize: { xs: '0.8rem', md: '0.9rem' },
                    letterSpacing: 0.5,
                    textTransform: 'uppercase',
                }}
            >
                {label}
            </Typography>
        </Box>
    );
}

export default function StatsStrip() {
    const [started, setStarted] = useState(false);
    const [stats, setStats] = useState(DEFAULT_STATS);
    const ref = useRef(null);

    useEffect(() => {
        let active = true;
        axiosClient.get('/auth/public/landing-stats/')
            .then((res) => {
                if (!active) return;
                const data = res.data || {};
                setStats((prev) => prev.map((s) => ({
                    ...s,
                    target: Number.isFinite(data[s.key]) ? data[s.key] : s.target,
                })));
            })
            .catch(() => {});
        return () => { active = false; };
    }, []);

    useEffect(() => {
        const el = ref.current;
        if (!el) return;

        let observer;

        // Defer observer setup until first scroll so a page refresh
        // with the section already in the viewport doesn't trigger the count-up.
        const setupObserver = () => {
            observer = new IntersectionObserver(
                ([entry]) => {
                    if (entry.isIntersecting) {
                        setStarted(true);
                        observer.disconnect();
                    }
                },
                { threshold: 0.3 }
            );
            observer.observe(el);
        };

        const onScroll = () => {
            window.removeEventListener('scroll', onScroll);
            setupObserver();
        };
        window.addEventListener('scroll', onScroll, { passive: true });

        return () => {
            window.removeEventListener('scroll', onScroll);
            if (observer) observer.disconnect();
        };
    }, []);

    return (
        <Box ref={ref} sx={{ py: { xs: 4, md: 5 }, bgcolor: '#F1F5F9' }}>
            <Container maxWidth="lg">
                <Grid container spacing={2} justifyContent="center">
                    {stats.map((stat, i) => (
                        <Grid
                            item
                            xs={12}
                            sm={4}
                            md={4}
                            key={stat.key}
                            sx={{
                                borderRight: {
                                    xs: 'none',
                                    sm: i < stats.length - 1 ? '1px solid #E2E8F0' : 'none',
                                },
                            }}
                        >
                            <StatItem
                                target={stat.target}
                                suffix={stat.suffix}
                                label={stat.label}
                                started={started}
                            />
                        </Grid>
                    ))}
                </Grid>
            </Container>
        </Box>
    );
}
