/**
 * ModalManager Component
 * 
 * Manages all modals in the IDE.
 * Centralizes modal logic and prevents multiple modals open at once.
 * Follows SRP: Single responsibility is modal orchestration.
 */

import React from 'react';
import PropTypes from 'prop-types';
import ApprovalModal from '../ApprovalModal';
import ConfigurationPanel from '../ConfigurationPanel';
import UserPreferencesPanel from '../UserPreferencesPanel';

export function ModalManager({
  approval,
  config,
  preferences,
}) {
  return (
    <>
      {/* Approval Modal */}
      {approval.visible && (
        <ApprovalModal
          approval={approval.data}
          onApprove={approval.onApprove}
          onReject={approval.onReject}
          onClose={approval.onClose}
          loading={approval.loading}
        />
      )}
      
      {/* Config Modal */}
      {config.visible && (
        <div className="modal-overlay" onClick={config.onClose}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <ConfigurationPanel />
            <button onClick={config.onClose} className="btn-close">
              Close
            </button>
          </div>
        </div>
      )}
      
      {/* Preferences Modal */}
      {preferences.visible && (
        <UserPreferencesPanel onClose={preferences.onClose} />
      )}
    </>
  );
}

ModalManager.propTypes = {
  approval: PropTypes.shape({
    visible: PropTypes.bool.isRequired,
    data: PropTypes.object,
    loading: PropTypes.bool.isRequired,
    onApprove: PropTypes.func.isRequired,
    onReject: PropTypes.func.isRequired,
    onClose: PropTypes.func.isRequired,
  }).isRequired,
  config: PropTypes.shape({
    visible: PropTypes.bool.isRequired,
    onClose: PropTypes.func.isRequired,
  }).isRequired,
  preferences: PropTypes.shape({
    visible: PropTypes.bool.isRequired,
    onClose: PropTypes.func.isRequired,
  }).isRequired,
};

export default ModalManager;

