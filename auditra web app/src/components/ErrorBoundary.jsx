import { Component } from 'react';
import { Box, Typography, Button, Paper } from '@mui/material';
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline';

export default class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error, info) {
    if (import.meta.env.DEV) {
      console.error('Dashboard render error:', error, info);
    }
  }

  componentDidUpdate(prevProps) {
    if (this.state.hasError && prevProps.resetKey !== this.props.resetKey) {
      this.setState({ hasError: false });
    }
  }

  handleReload = () => {
    this.setState({ hasError: false });
    window.location.reload();
  };

  render() {
    if (this.state.hasError) {
      return (
        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '60vh', p: 3 }}>
          <Paper sx={{ p: 4, maxWidth: 420, textAlign: 'center', borderRadius: 3 }}>
            <ErrorOutlineIcon color="error" sx={{ fontSize: 48, mb: 1 }} />
            <Typography variant="h6" fontWeight={700} gutterBottom>
              Something went wrong
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
              This page ran into an unexpected error. Reloading usually fixes it.
            </Typography>
            <Button variant="contained" onClick={this.handleReload}>Reload page</Button>
          </Paper>
        </Box>
      );
    }
    return this.props.children;
  }
}
