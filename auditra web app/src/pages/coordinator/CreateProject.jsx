import { useState, useCallback } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import {
  Box, Typography, Card, CardContent, TextField, Button, Grid, Alert,
  CircularProgress, InputAdornment, IconButton, LinearProgress,
} from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import ErrorIcon from '@mui/icons-material/Error';
import InfoIcon from '@mui/icons-material/Info';
import AssignmentIcon from '@mui/icons-material/Assignment';
import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import DeleteIcon from '@mui/icons-material/Delete';
import DescriptionIcon from '@mui/icons-material/Description';
import projectService from '../../services/projectService';
import ProjectDetailsFields from '../../components/ProjectDetailsFields';
import { extractApiErrorMessage } from '../../utils/helpers';
import { validationRules, sanitizePhoneInput } from '../../utils/formValidation';
import { useDocumentManagement } from '../../hooks/useDocumentManagement';

const PHONE_FIELDS = ['client_phone', 'agent_phone'];
const PRIORITIES = ['high', 'medium', 'low'];
const LICENSE_NUMBER_REGEX = /^[A-Za-z0-9][A-Za-z0-9/-]{2,29}$/;
const MAX_ESTIMATED_VALUE = 1000000000;

// Every validated field, in the order they appear in the form.
const VALIDATED_FIELDS = [
  'title', 'description', 'priority', 'start_date', 'end_date', 'estimated_value',
  'client_name', 'client_email', 'client_phone', 'client_company', 'client_address',
  'agent_name', 'agent_email', 'agent_phone', 'agent_license_number', 'agent_address',
];

// Fields whose error depends on another field, so they are re-checked together.
const DEPENDENT_FIELDS = {
  start_date: ['end_date'],
  client_email: ['client_name'],
  agent_email: ['agent_name'],
};

const fieldsToCheck = (name) => [name, ...(DEPENDENT_FIELDS[name] || [])];

export default function CreateProject() {
  const navigate = useNavigate();
  const location = useLocation();

  // Pre-fill from assigned submission (passed via route state from AssignedSubmissions)
  const submissionData = location.state?.submissionData || null;
  const submissionId = location.state?.submissionId || null;

  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [formErrors, setFormErrors] = useState({});
  const [touched, setTouched] = useState({}); // fields the user has already left
  const [form, setForm] = useState({
    title: submissionData?.project_title || '',
    description: submissionData?.project_description || '',
    priority: 'medium',
    start_date: '',
    end_date: '',
    estimated_value: '50000',
    client_name: submissionData
      ? [submissionData.first_name, submissionData.last_name].filter(Boolean).join(' ')
      : '',
    client_email: submissionData?.email || '',
    client_phone: submissionData?.phone || '',
    client_address: submissionData?.address || '',
    client_company: submissionData?.company_name || '',
    agent_name: submissionData?.agent_name || '',
    agent_email: submissionData?.agent_email || '',
    agent_phone: submissionData?.agent_phone || '',
    agent_address: '',
    agent_license_number: '',
  });

  // Email check states
  const [clientEmailStatus, setClientEmailStatus] = useState(null); // null | 'checking' | 'found' | 'not_found' | 'mismatch' | 'error'
  const [clientEmailMessage, setClientEmailMessage] = useState('');
  const [agentEmailStatus, setAgentEmailStatus] = useState(null);
  const [agentEmailMessage, setAgentEmailMessage] = useState('');
  const [dbClient, setDbClient] = useState(null);

  const today = new Date().toISOString().split('T')[0];

  // Use document management hook (projectId will be set after project creation)
  const {
    stagedDocuments,
    uploadingDocs,
    error: docError,
    handleAddDocument,
    handleRemoveStagedDoc,
    handleDocNameChange,
  } = useDocumentManagement(null);

  // Validates a single field and returns an error message ('' when the field is fine).
  const validateSingleField = useCallback((name, rawValue, data, client = dbClient) => {
    const value = typeof rawValue === 'string' ? rawValue : String(rawValue ?? '');
    const trimmed = value.trim();

    switch (name) {
      case 'title': {
        const r = validationRules.project_title.validate(trimmed);
        return r.valid ? '' : r.error;
      }
      case 'description': {
        const r = validationRules.project_description.validate(trimmed);
        return r.valid ? '' : r.error;
      }
      case 'priority':
        return PRIORITIES.includes(trimmed) ? '' : 'Select a priority';
      case 'start_date':
        if (!trimmed) return 'Start date is required';
        if (trimmed < today) return 'Start date must be today or a future date';
        return '';
      case 'end_date':
        if (!trimmed) return 'End date is required';
        if (data.start_date && trimmed <= data.start_date) return 'End date must be after the start date';
        return '';
      case 'estimated_value': {
        if (!trimmed) return 'Estimated value is required';
        const amount = Number(trimmed);
        if (!Number.isFinite(amount)) return 'Estimated value must be a valid number';
        if (amount <= 0) return 'Estimated value must be greater than zero';
        if (!/^\d+(\.\d{1,2})?$/.test(trimmed)) return 'Estimated value can have at most 2 decimal places';
        if (amount > MAX_ESTIMATED_VALUE) return 'Estimated value must not exceed Rs. 1,000,000,000';
        return '';
      }
      case 'client_name': {
        if (!trimmed) return 'Client name is required';
        const r = validationRules.name.validate(trimmed, 'Client name');
        if (!r.valid) return r.error;
        if (client && trimmed.toLowerCase() !== client.full_name.trim().toLowerCase()) {
          return `Client name must match the registered account: "${client.full_name}"`;
        }
        return '';
      }
      case 'client_email': {
        if (!trimmed) return 'Client email is required';
        const r = validationRules.email.validate(trimmed);
        return r.valid ? '' : r.error;
      }
      case 'agent_email': {
        if (!trimmed) return '';
        const r = validationRules.email.validate(trimmed);
        return r.valid ? '' : r.error;
      }
      case 'agent_name': {
        if (!trimmed) {
          return data.agent_email.trim() ? 'Agent name is required when an agent email is provided' : '';
        }
        const r = validationRules.name.validate(trimmed, 'Agent name');
        return r.valid ? '' : r.error;
      }
      case 'client_phone':
      case 'agent_phone': {
        if (!trimmed) return '';
        const r = validationRules.phone.validate(trimmed);
        return r.valid ? '' : r.error;
      }
      case 'client_address':
      case 'agent_address': {
        const r = validationRules.address.validate(trimmed);
        return r.valid ? '' : r.error;
      }
      case 'client_company': {
        const r = validationRules.company_name.validate(trimmed);
        return r.valid ? '' : r.error;
      }
      case 'agent_license_number':
        if (!trimmed) return '';
        return LICENSE_NUMBER_REGEX.test(trimmed)
          ? ''
          : 'License number must be 3-30 characters using letters, numbers, hyphens or slashes';
      default:
        return '';
    }
  }, [today, dbClient]);

  // Recomputes the given fields in an error map. A field only shows an error once it is touched.
  const applyFieldErrors = useCallback((errors, fields, data, touchedMap, client) => {
    const next = { ...errors };
    fields.forEach((field) => {
      const message = touchedMap[field] ? validateSingleField(field, data[field], data, client) : '';
      if (message) next[field] = message;
      else delete next[field];
    });
    return next;
  }, [validateSingleField]);

  // Marks a field as visited, refreshes its error (and any field that depends on it),
  // and returns that field's own error message.
  const runFieldValidation = (name, data = form, client = dbClient) => {
    const nextTouched = { ...touched, [name]: true };
    setTouched(nextTouched);
    setFormErrors((prev) => applyFieldErrors(prev, fieldsToCheck(name), data, nextTouched, client));
    return validateSingleField(name, data[name], data, client);
  };

  const handleChange = (e) => {
    const { name } = e.target;
    const value = PHONE_FIELDS.includes(name) ? sanitizePhoneInput(e.target.value) : e.target.value;
    const nextForm = { ...form, [name]: value };
    setForm(nextForm);
    // Untouched fields stay quiet; a field the user already left updates live as it is corrected.
    setFormErrors((prev) => applyFieldErrors(prev, fieldsToCheck(name), nextForm, touched, dbClient));

    // Live validation for client_name if we fetched a dbClient
    if (name === 'client_name' && dbClient) {
      if (value.trim().toLowerCase() !== dbClient.full_name.trim().toLowerCase()) {
        setClientEmailStatus('error');
        setClientEmailMessage(`Client name mismatch. Correct name is "${dbClient.full_name}".`);
      } else {
        setClientEmailStatus('found');
        setClientEmailMessage(`Account found: ${dbClient.full_name} (${dbClient.email})`);
      }
    }
  };

  // Shows a field's error as soon as the user moves on to the next field.
  const handleBlur = (e) => {
    const { name } = e.target;
    if (name) runFieldValidation(name);
  };

  const hasSubmissionAgentDetails = Boolean(
    submissionData?.agent_name || submissionData?.agent_email || submissionData?.agent_phone
  );
  const showAgentSection = !submissionData || hasSubmissionAgentDetails;

  const validateForm = () => {
    const allTouched = {};
    VALIDATED_FIELDS.forEach((field) => { allTouched[field] = true; });
    setTouched(allTouched);

    const errors = applyFieldErrors({}, VALIDATED_FIELDS, form, allTouched, dbClient);

    // A role conflict reported by the server blocks submission as well.
    if (clientEmailStatus === 'mismatch') {
      errors.client_email = clientEmailMessage || 'This email cannot be used for a client role';
    }
    if (form.agent_email.trim() && agentEmailStatus === 'mismatch') {
      errors.agent_email = agentEmailMessage || 'This email cannot be used for an agent role';
    }

    setFormErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const checkEmail = useCallback(async (email, roleType, setStatus, setMessage) => {
    if (!email || !email.includes('@')) {
      setStatus(null);
      setMessage('');
      return null;
    }

    setStatus('checking');
    setMessage('');
    try {
      const res = await projectService.checkEmail(email, roleType);
      const data = res.data;
      if (data.exists && !data.role_mismatch) {
        setStatus('found');
        setMessage(`Account found: ${data.user.full_name} (${data.user.email})`);
        return data.user;
      } else if (data.exists && data.role_mismatch) {
        setStatus('mismatch');
        setMessage(data.message);
      } else {
        setStatus('not_found');
        setMessage('No account found — will be created on submit');
      }
    } catch {
      setStatus('error');
      setMessage('Failed to check email');
    }
    return null;
  }, []);

  const handleClientEmailBlur = async () => {
    if (runFieldValidation('client_email')) {
      setClientEmailStatus(null);
      setClientEmailMessage('');
      setDbClient(null);
      return;
    }

    const user = await checkEmail(form.client_email, 'client', setClientEmailStatus, setClientEmailMessage);
    if (user) {
      setDbClient(user);
      const currentName = form.client_name.trim();
      const dbName = user.full_name.trim();

      if (currentName && currentName.toLowerCase() !== dbName.toLowerCase()) {
        setClientEmailStatus('error');
        setClientEmailMessage(`Client name mismatch. Correct name is "${dbName}".`);
        setTouched((prev) => ({ ...prev, client_name: true }));
        setFormErrors((prev) => ({
          ...prev,
          client_name: `Client name must match the registered account: "${dbName}"`,
        }));
      } else {
        // If empty or matches, auto-fill details
        setForm((prev) => ({
          ...prev,
          client_name: dbName,
          client_phone: user.phone || prev.client_phone,
          client_company: user.company || prev.client_company,
          client_address: user.address || prev.client_address,
        }));
        setClientEmailStatus('found');
        setClientEmailMessage(`Account found: ${dbName} (${user.email})`);
        setFormErrors((prev) => { const next = { ...prev }; delete next.client_name; return next; });
      }
    } else {
      setDbClient(null);
    }
  };

  const handleAgentEmailBlur = () => {
    const invalid = runFieldValidation('agent_email');
    if (invalid || !form.agent_email.trim()) {
      setAgentEmailStatus(null);
      setAgentEmailMessage('');
      return;
    }
    checkEmail(form.agent_email, 'agent', setAgentEmailStatus, setAgentEmailMessage);
  };

  const getEmailAdornment = (status) => {
    if (!status) return null;
    if (status === 'checking') return <CircularProgress size={20} />;
    if (status === 'found') return <CheckCircleIcon sx={{ color: 'success.main' }} />;
    if (status === 'not_found') return <InfoIcon sx={{ color: 'info.main' }} />;
    if (status === 'mismatch') return <ErrorIcon sx={{ color: 'warning.main' }} />;
    if (status === 'error') return <ErrorIcon sx={{ color: 'error.main' }} />;
    return null;
  };

  const getEmailHelperColor = (status) => {
    if (status === 'found') return '#1565C0';
    if (status === 'not_found') return '#1565C0';
    if (status === 'mismatch') return '#1E88E5';
    if (status === 'error') return '#DC2626';
    return undefined;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!validateForm()) return;

    setLoading(true);

    // Package data: flat project fields + client_info/agent_info as JSON objects
    const payload = {
      title: form.title,
      description: form.description,
      priority: form.priority,
      start_date: form.start_date || null,
      end_date: form.end_date || null,
      estimated_value: parseFloat(form.estimated_value) || 50000,
    };

    // Include submission_id if creating from an assigned submission
    if (submissionId) {
      payload.submission_id = submissionId;
    }

    // Build client_info if email is provided
    if (form.client_email) {
      payload.client_info = {
        name: form.client_name,
        email: form.client_email,
        phone: form.client_phone,
        address: form.client_address,
        company: form.client_company,
      };
    }

    // Build agent_info if email is provided
    if (form.agent_email) {
      payload.agent_info = {
        name: form.agent_name,
        email: form.agent_email,
        phone: form.agent_phone,
        address: form.agent_address,
        license_number: form.agent_license_number,
      };
    }

    try {
      const res = await projectService.createProject(payload);
      const newProjectId = res.data.id;

      // Upload staged documents sequentially
      if (stagedDocuments.length > 0) {
        for (let i = 0; i < stagedDocuments.length; i++) {
          const doc = stagedDocuments[i];
          try {
            await projectService.uploadDocument({
              project: newProjectId,
              file: doc.file,
              name: doc.name,
            });
          } catch (uploadErr) {
            console.error(`Failed to upload document: ${doc.name}`, uploadErr);
          }
        }
      }

      navigate('/dashboard/projects');
    } catch (err) {
      if (err.response?.status === 400) {
        setError('Invalid data provided. Please check all fields.');
      } else if (err.response?.status === 403) {
        setError('You do not have permission to create projects.');
      } else if (err.response?.status === 500) {
        setError('Server error. Please try again later.');
      } else {
        setError(extractApiErrorMessage(err, 'Failed to create project'));
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>Create New Project</Typography>
      {submissionData && (
        <Alert icon={<AssignmentIcon />} severity="info" sx={{ mb: 2 }}>
          Creating project from client submission by{' '}
          <strong>
            {[submissionData.first_name, submissionData.last_name].filter(Boolean).join(' ') || submissionData.email}
          </strong>.
        </Alert>
      )}
      {!submissionId && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>Admin Approval Required</Typography>
          <Typography variant="body2">
            Projects created directly require admin approval before they can be started.
          </Typography>
        </Alert>
      )}
      {error && <Alert severity="error" sx={{ mb: 2, whiteSpace: 'pre-line' }}>{error}</Alert>}
      {docError && <Alert severity="error" sx={{ mb: 2, whiteSpace: 'pre-line' }}>{docError}</Alert>}
      <form onSubmit={handleSubmit}>
        <Card sx={{ mb: 3 }}>
          <CardContent sx={{ p: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Project Details</Typography>
            <ProjectDetailsFields
              form={form}
              onChange={handleChange}
              onBlur={handleBlur}
              titleError={formErrors.title}
              titleHelperText={formErrors.title}
              descriptionError={formErrors.description}
              descriptionHelperText={formErrors.description}
              startDateRequired
              endDateRequired
              startDateMin={today}
              endDateMin={form.start_date || today}
              startDateError={formErrors.start_date}
              startDateHelperText={formErrors.start_date}
              endDateError={formErrors.end_date}
              endDateHelperText={formErrors.end_date}
              estimatedValueError={formErrors.estimated_value}
              estimatedValueHelperText={formErrors.estimated_value || 'Client must pay this amount before project starts'}
              estimatedValueMin={1}
            />
          </CardContent>
        </Card>
        <Card sx={{ mb: 3 }}>
          <CardContent sx={{ p: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Client Information</Typography>
            <Grid container spacing={2}>
              <Grid item xs={12} sm={6}>
                <TextField
                  fullWidth
                  label="Client Name"
                  name="client_name"
                  value={form.client_name}
                  onChange={handleChange}
                  onBlur={handleBlur}
                  required
                  error={!!formErrors.client_name}
                  helperText={formErrors.client_name}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  fullWidth
                  label="Client Email"
                  name="client_email"
                  type="email"
                  value={form.client_email}
                  onChange={(e) => {
                    handleChange(e);
                    if (clientEmailStatus) { 
                      setClientEmailStatus(null); 
                      setClientEmailMessage(''); 
                      setDbClient(null);
                      setFormErrors((prev) => { const next = { ...prev }; delete next.client_name; return next; });
                    }
                  }}
                  onBlur={handleClientEmailBlur}
                  required
                  error={!!formErrors.client_email}
                  helperText={formErrors.client_email || clientEmailMessage}
                  FormHelperTextProps={{ sx: { color: formErrors.client_email ? 'error.main' : getEmailHelperColor(clientEmailStatus) } }}
                  InputProps={{
                    endAdornment: clientEmailStatus ? (
                      <InputAdornment position="end">{getEmailAdornment(clientEmailStatus)}</InputAdornment>
                    ) : null,
                  }}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  fullWidth
                  label="Client Phone"
                  name="client_phone"
                  value={form.client_phone}
                  onChange={handleChange}
                  onBlur={handleBlur}
                  placeholder="+94XXXXXXXXX"
                  error={!!formErrors.client_phone}
                  helperText={formErrors.client_phone}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  fullWidth
                  label="Company"
                  name="client_company"
                  value={form.client_company}
                  onChange={handleChange}
                  onBlur={handleBlur}
                  error={!!formErrors.client_company}
                  helperText={formErrors.client_company}
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Client Address"
                  name="client_address"
                  value={form.client_address}
                  onChange={handleChange}
                  onBlur={handleBlur}
                  error={!!formErrors.client_address}
                  helperText={formErrors.client_address}
                />
              </Grid>
            </Grid>
            {clientEmailStatus === 'not_found' && form.client_email && (
              <Alert severity="info" sx={{ mt: 2 }}>
                A new client account will be created when you submit this project. Login credentials will be emailed to {form.client_email}.
              </Alert>
            )}
            {clientEmailStatus === 'mismatch' && (
              <Alert severity="warning" sx={{ mt: 2 }}>
                {clientEmailMessage}. This email cannot be used for a client role.
              </Alert>
            )}
          </CardContent>
        </Card>
        {showAgentSection && (
          <Card sx={{ mb: 3 }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Agent Information (Optional)</Typography>
              <Grid container spacing={2}>
                <Grid item xs={12} sm={6}>
                  <TextField
                    fullWidth
                    label="Agent Name"
                    name="agent_name"
                    value={form.agent_name}
                    onChange={handleChange}
                    onBlur={handleBlur}
                    error={!!formErrors.agent_name}
                    helperText={formErrors.agent_name}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <TextField
                    fullWidth
                    label="Agent Email"
                    name="agent_email"
                    type="email"
                    value={form.agent_email}
                    onChange={(e) => {
                      handleChange(e);
                      if (agentEmailStatus) { setAgentEmailStatus(null); setAgentEmailMessage(''); }
                    }}
                    onBlur={handleAgentEmailBlur}
                    error={!!formErrors.agent_email}
                    helperText={formErrors.agent_email || agentEmailMessage}
                    FormHelperTextProps={{ sx: { color: formErrors.agent_email ? 'error.main' : getEmailHelperColor(agentEmailStatus) } }}
                    InputProps={{
                      endAdornment: agentEmailStatus ? (
                        <InputAdornment position="end">{getEmailAdornment(agentEmailStatus)}</InputAdornment>
                      ) : null,
                    }}
                  />
                </Grid>
                <Grid item xs={12} sm={4}>
                  <TextField
                    fullWidth
                    label="Agent Phone"
                    name="agent_phone"
                    value={form.agent_phone}
                    onChange={handleChange}
                    onBlur={handleBlur}
                    placeholder="+94XXXXXXXXX"
                    error={!!formErrors.agent_phone}
                    helperText={formErrors.agent_phone}
                  />
                </Grid>
                <Grid item xs={12} sm={4}>
                  <TextField
                    fullWidth
                    label="License Number"
                    name="agent_license_number"
                    value={form.agent_license_number}
                    onChange={handleChange}
                    onBlur={handleBlur}
                    error={!!formErrors.agent_license_number}
                    helperText={formErrors.agent_license_number}
                  />
                </Grid>
                <Grid item xs={12} sm={4}>
                  <TextField
                    fullWidth
                    label="Agent Address"
                    name="agent_address"
                    value={form.agent_address}
                    onChange={handleChange}
                    onBlur={handleBlur}
                    error={!!formErrors.agent_address}
                    helperText={formErrors.agent_address}
                  />
                </Grid>
              </Grid>
              {agentEmailStatus === 'not_found' && form.agent_email && (
                <Alert severity="info" sx={{ mt: 2 }}>
                  A new agent account will be created when you submit this project. Login credentials will be emailed to {form.agent_email}.
                </Alert>
              )}
              {agentEmailStatus === 'mismatch' && (
                <Alert severity="warning" sx={{ mt: 2 }}>
                  {agentEmailMessage}. This email cannot be used for an agent role.
                </Alert>
              )}
            </CardContent>
          </Card>
        )}
        <Card sx={{ mb: 3 }}>
          <CardContent sx={{ p: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Project Documents (Optional)</Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Attach documents to this project. Files will be uploaded after the project is created.
            </Typography>

            <Button
              variant="outlined"
              component="label"
              startIcon={<CloudUploadIcon />}
              sx={{ mb: stagedDocuments.length > 0 ? 2 : 0 }}
            >
              Add Files
              <input type="file" hidden multiple onChange={handleAddDocument} />
            </Button>

            {stagedDocuments.length > 0 && (
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                {stagedDocuments.map((doc) => (
                  <Box
                    key={doc.id}
                    sx={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      p: 1.5,
                      bgcolor: (t) => t.palette.custom?.cardInner || (t.palette.mode === 'dark' ? 'rgba(255,255,255,0.05)' : '#f5f7fa'),
                      borderRadius: 1,
                    }}
                  >
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flex: 1, minWidth: 0 }}>
                      <DescriptionIcon color="primary" fontSize="small" />
                      <TextField
                        variant="standard"
                        value={doc.name}
                        onChange={(e) => handleDocNameChange(doc.id, e.target.value)}
                        placeholder="Document name"
                        size="small"
                        sx={{ maxWidth: 300 }}
                      />
                      <Typography variant="caption" color="text.secondary" sx={{ whiteSpace: 'nowrap' }}>
                        ({(doc.file.size / 1024).toFixed(1)} KB)
                      </Typography>
                    </Box>
                    <IconButton size="small" onClick={() => handleRemoveStagedDoc(doc.id)}>
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </Box>
                ))}
              </Box>
            )}

            {uploadingDocs && (
              <Box sx={{ mt: 2 }}>
                <LinearProgress />
              </Box>
            )}
          </CardContent>
        </Card>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <Button variant="outlined" onClick={() => navigate('/dashboard/projects')}>Cancel</Button>
          <Button type="submit" variant="contained" disabled={loading || uploadingDocs}>
            {uploadingDocs ? 'Uploading Documents...' : loading ? 'Creating...' : 'Create Project'}
          </Button>
        </Box>
      </form>
    </Box>
  );
}
