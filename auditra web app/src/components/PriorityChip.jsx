import Chip from '@mui/material/Chip';
import { useTheme } from '@mui/material/styles';
import { capitalize, getPriorityColor } from '../utils/helpers';

export default function PriorityChip({
  priority,
  size = 'small',
  width = 110,
  fontSize = 12,
}) {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';
  const color = getPriorityColor(priority, isDark);

  return (
    <Chip
      label={capitalize(priority)}
      size={size}
      sx={{
        bgcolor: `${color}20`,
        color,
        fontWeight: 600,
        fontSize,
        width,
        justifyContent: 'center',
        border: `1px solid ${color}50`,
      }}
    />
  );
}
