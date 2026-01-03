/**
 * Domain model representing a collection of memory sections.
 * 
 * Strict OOP principles:
 * - Immutable with Object.freeze()
 * - Validation in constructor
 * - Transformation methods return NEW instances
 */
import { MemorySection } from './MemorySection';

export class Memory {
  /**
   * Create a new Memory
   * @param {Object} params Memory parameters
   * @param {string} params.agentType Agent type (daedalus, sisyphus, etc.)
   * @param {Array<MemorySection>} params.sections Array of MemorySection instances
   */
  constructor({ agentType, sections = [] }) {
    // Validation
    if (!agentType || typeof agentType !== 'string') {
      throw new Error(`Memory: agentType is required and must be a string, got ${typeof agentType}`);
    }
    if (!Array.isArray(sections)) {
      throw new Error(`Memory: sections must be an array, got ${typeof sections}`);
    }

    // Validate all sections are MemorySection instances
    sections.forEach((section, index) => {
      if (!(section instanceof MemorySection)) {
        throw new Error(`Memory: sections[${index}] must be a MemorySection instance, got ${section?.constructor?.name}`);
      }
    });

    this._agentType = agentType;
    this._sections = Object.freeze([...sections]);

    Object.freeze(this);
  }

  // Getters
  get agentType() { return this._agentType; }
  get sections() { return this._sections; }

  /**
   * Get number of sections
   * @returns {number}
   */
  get length() {
    return this._sections.length;
  }

  /**
   * Check if memory is empty
   * @returns {boolean}
   */
  isEmpty() {
    return this._sections.length === 0;
  }

  /**
   * Get section by name
   * @param {string} sectionName Section name
   * @returns {MemorySection|null}
   */
  getSectionByName(sectionName) {
    return this._sections.find(s => s.sectionName === sectionName) || null;
  }

  /**
   * Get all section names
   * @returns {Array<string>}
   */
  getSectionNames() {
    return this._sections.map(s => s.sectionName);
  }

  /**
   * Get non-empty sections
   * @returns {Array<MemorySection>}
   */
  getNonEmptySections() {
    return this._sections.filter(s => !s.isEmpty());
  }

  /**
   * Get empty sections
   * @returns {Array<MemorySection>}
   */
  getEmptySections() {
    return this._sections.filter(s => s.isEmpty());
  }

  /**
   * Check if section exists
   * @param {string} sectionName Section name
   * @returns {boolean}
   */
  hasSection(sectionName) {
    return this._sections.some(s => s.sectionName === sectionName);
  }

  /**
   * Add or update section
   * Returns NEW instance
   * @param {MemorySection} section Section to add/update
   * @returns {Memory}
   */
  updateSection(section) {
    if (!(section instanceof MemorySection)) {
      throw new Error(`Memory.updateSection: section must be a MemorySection instance, got ${section?.constructor?.name}`);
    }

    const existingIndex = this._sections.findIndex(s => s.sectionName === section.sectionName);
    
    let newSections;
    if (existingIndex >= 0) {
      // Update existing
      newSections = [...this._sections];
      newSections[existingIndex] = section;
    } else {
      // Add new
      newSections = [...this._sections, section];
    }

    return new Memory({
      agentType: this._agentType,
      sections: newSections
    });
  }

  /**
   * Remove section
   * Returns NEW instance
   * @param {string} sectionName Section name to remove
   * @returns {Memory}
   */
  removeSection(sectionName) {
    const newSections = this._sections.filter(s => s.sectionName !== sectionName);

    return new Memory({
      agentType: this._agentType,
      sections: newSections
    });
  }

  /**
   * Serialize to JSON
   * @returns {Object}
   */
  toJSON() {
    return {
      agent_type: this._agentType,
      sections: this._sections.map(s => s.toJSON()),
      count: this._sections.length
    };
  }

  /**
   * Create Memory from JSON
   * @param {Object} json JSON data
   * @returns {Memory}
   */
  static fromJSON(json) {
    if (!json || typeof json !== 'object') {
      throw new Error('Memory.fromJSON: json must be an object');
    }

    const agentType = json.agent_type || json.agentType;
    const sections = (json.sections || []).map(sJson => MemorySection.fromJSON(sJson));

    return new Memory({
      agentType,
      sections
    });
  }

  /**
   * Create empty memory
   * @param {string} agentType Agent type
   * @returns {Memory}
   */
  static empty(agentType) {
    return new Memory({
      agentType,
      sections: []
    });
  }
}


