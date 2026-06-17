export const getMediaUrl = (url) => {
  if (!url) return '';
  
  // If the url is absolute but points to localhost/127.0.0.1 while the app is hosted elsewhere, 
  // we want to fix it by converting it to a relative url first
  let cleanUrl = url;
  if (url.startsWith('http://127.0.0.1') || url.startsWith('http://localhost')) {
    if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
      try {
        const urlObj = new URL(url);
        cleanUrl = urlObj.pathname + urlObj.search;
      } catch (e) {
        // ignore
      }
    }
  }

  if (cleanUrl.startsWith('http')) return cleanUrl;
  
  let apiUrl = import.meta.env.VITE_API_URL;
  if (!apiUrl) {
    if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
      apiUrl = `${window.location.origin}/api`;
    } else {
      apiUrl = 'http://localhost:8000/api';
    }
  } else if (apiUrl.startsWith('/')) {
    apiUrl = `${window.location.origin}${apiUrl}`;
  } else if (window.location.protocol === 'https:' && apiUrl.startsWith('http://')) {
    apiUrl = apiUrl.replace(/^http:\/\//i, 'https://');
  }
  
  let baseUrl = apiUrl.replace(/\/api\/?$/, '');
  return `${baseUrl}${cleanUrl.startsWith('/') ? '' : '/'}${cleanUrl}`;
};
