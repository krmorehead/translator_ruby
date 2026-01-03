import { useState } from 'prop-types';
import PropTypes from 'prop-types';
import { useCheckpointStore } from '../store/checkpointStore';

function CreateCheckpointDialog({ onClose, onSuccess }) {
  const { createCheckpoint, loading } = useCheckpointStore();
  const [message, setMessage] = useState('');
  const [executionId, setExecutionId] = useState('');
  const [milestoneId, setMilestoneId] = useState('');
  const [isBackup, setIsBackup] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!message.trim()) {
      setError('Message is required');
      return;
    }

    const metadata = {};
    if (executionId) metadata.execution_id = executionId;
    if (milestoneId) metadata.milestone_id = milestoneId;
    metadata.is_backup = isBackup;

    const result = await createCheckpoint(message, metadata);
    
    if (result) {
      onSuccess();
    } else {
      setError('Failed to create checkpoint');
    }
  };

  return (
    <div className="dialog-overlay" onClick={onClose}>
      <div className="dialog" onClick={(e) => e.stopPropagation()}>
        <div className="dialog-header">
          <h2>Create Checkpoint</h2>
          <button onClick={onClose} className="close-btn">×</button>
        </div>

        <form onSubmit={handleSubmit} className="dialog-content">
          {error && <div className="error-message">{error}</div>}

          <div className="form-group">
            <label htmlFor="message">
              Message <span className="required">*</span>
            </label>
            <input
              id="message"
              type="text"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="Describe this checkpoint..."
              className="form-input"
              disabled={loading}
              autoFocus
            />
          </div>

          <div className="form-group">
            <label htmlFor="executionId">Execution ID (optional)</label>
            <input
              id="executionId"
              type="text"
              value={executionId}
              onChange={(e) => setExecutionId(e.target.value)}
              placeholder="Link to execution..."
              className="form-input"
              disabled={loading}
            />
          </div>

          <div className="form-group">
            <label htmlFor="milestoneId">Milestone ID (optional)</label>
            <input
              id="milestoneId"
              type="text"
              value={milestoneId}
              onChange={(e) => setMilestoneId(e.target.value)}
              placeholder="Link to milestone..."
              className="form-input"
              disabled={loading}
            />
          </div>

          <div className="form-group checkbox-group">
            <label>
              <input
                type="checkbox"
                checked={isBackup}
                onChange={(e) => setIsBackup(e.target.checked)}
                disabled={loading}
              />
              <span>Mark as backup checkpoint</span>
            </label>
          </div>

          <div className="dialog-actions">
            <button
              type="button"
              onClick={onClose}
              className="btn-secondary"
              disabled={loading}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="btn-primary"
              disabled={loading || !message.trim()}
            >
              {loading ? 'Creating...' : 'Create Checkpoint'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

CreateCheckpointDialog.propTypes = {
  onClose: PropTypes.func.isRequired,
  onSuccess: PropTypes.func.isRequired,
};

export default CreateCheckpointDialog;


