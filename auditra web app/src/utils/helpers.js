export const getStatusColor = (status) => {
  const colors = {
    pending: '#1E88E5',
    pending: '#1E88E5',
    active: '#2563EB',
    in_progress: '#2563EB',
    completed: '#1565C0',
    cancelled: '#0D47A1',
    approved: '#1565C0',
    rejected: '#D32F2F',
    submitted: '#1565C0',
    reviewed: '#0D47A1',
    accepted: '#1565C0',
    md_approved: '#1565C0',
    present: '#1565C0',
    absent: '#D32F2F',
    half_day: '#1E88E5',
  };
  return colors[status] || '#90CAF9';
  return colors[status] || '#90CAF9';
};

export const getPriorityColor = (priority, isDark = false) => {
  if (isDark) {
    const colors = {
      urgent: '#ea80fc',  // light purple
      high: '#ff8a80',    // light red
      medium: '#ffb74d',  // light orange
      low: '#81c784',     // light green
    };
    return colors[priority] || '#94A3B8';
  }
  const colors = {
    urgent: '#6A1B9A',  // deep purple
    high: '#d32f2f',    // red
    medium: '#ed6c02',  // orange
    low: '#2e7d32',     // green
  };
  return colors[priority] || '#64748B';
};

export const getPriorityBgColor = (priority, isDark = false) => {
  if (isDark) {
    const colors = {
      urgent: 'rgba(234, 128, 252, 0.16)', // translucent light purple
      high: 'rgba(255, 138, 128, 0.16)',   // translucent light red
      medium: 'rgba(255, 183, 77, 0.16)',  // translucent light orange
      low: 'rgba(129, 199, 132, 0.16)',    // translucent light green
    };
    return colors[priority] || 'rgba(148, 163, 184, 0.12)';
  }
  const colors = {
    urgent: '#f3e5f5',
    high: '#fdecea',
    medium: '#fff3e0',
    low: '#e8f5e9',
  };
  return colors[priority] || '#f5f5f5';
};

export const capitalize = (str) => {
  if (!str) return '';
  return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
};

export const formatDate = (dateString) => {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

export const formatDateTime = (dateString) => {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

export const formatCurrency = (amount) => {
  if (amount == null) return '-';
  return new Intl.NumberFormat('en-LK', {
    style: 'currency',
    currency: 'LKR',
    minimumFractionDigits: 0,
  }).format(amount);
};

export const formatFileSize = (bytes) => {
  if (!bytes) return '-';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};

export const extractApiErrorMessage = (err, fallback = 'Request failed') => {
  const data = err?.response?.data;

  if (data && typeof data === 'object') {
    if (data.error) return data.error;
    if (data.detail) return data.detail;
    if (data.message) return data.message;

    const msgs = Object.entries(data).map(([key, value]) => {
      const fieldName = key.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
      const message = Array.isArray(value) ? value.join(', ') : value;
      return `${fieldName}: ${message}`;
    });

    if (msgs.length > 0) {
      return msgs.join('\n');
    }
  }

  return err?.message || fallback;
};
