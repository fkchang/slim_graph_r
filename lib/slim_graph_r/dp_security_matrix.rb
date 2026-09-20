# frozen_string_literal: true
module SlimGraphR
  SecurityRole = Struct.new(:id, :label, :code, keyword_init: true)
  SecurityComponent = Struct.new(:id, :label, :hint, keyword_init: true)
  SecurityPermission = Struct.new(:component, :role, :label, :level, :note, :focal, keyword_init: true)

  module DPSecurityMatrixDSL
    LEVELS = %i[admin write read deny unknown].freeze
    LEVEL_LABELS = {
      admin: 'Admin', write: 'Read/write', read: 'Read', deny: 'No access', unknown: 'Unknown'
    }.freeze
    SECURITY_UNSET = Object.new.freeze

    attr_reader :security_roles, :security_components, :security_permissions

    def initialize(...)
      @security_roles = []
      @security_components = []
      @security_permissions = []
      super
    end

    def role(id, label = SECURITY_UNSET, code: SECURITY_UNSET, **options)
      unless type == :dp_security_matrix
        options[:code] = code unless code.equal?(SECURITY_UNSET)
        return label.equal?(SECURITY_UNSET) ? super(id, **options) : super(id, label, **options)
      end
      raise Error, "Unknown security-matrix role options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'Role label is required and must not be blank' if label.equal?(SECURITY_UNSET)
      clean_id, clean_label = security_identity(id, label, 'Role')
      clean_code = code.equal?(SECURITY_UNSET) ? nil : security_text(code, 'Role code')
      @security_roles << SecurityRole.new(id: clean_id, label: clean_label, code: clean_code)
    end

    def component(id, label = SECURITY_UNSET, hint: SECURITY_UNSET, **options)
      unless type == :dp_security_matrix
        options[:hint] = hint unless hint.equal?(SECURITY_UNSET)
        return label.equal?(SECURITY_UNSET) ? super(id, **options) : super(id, label, **options)
      end
      raise Error, "Unknown security-matrix component options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'Component label is required and must not be blank' if label.equal?(SECURITY_UNSET)
      clean_id, clean_label = security_identity(id, label, 'Component')
      clean_hint = hint.equal?(SECURITY_UNSET) ? nil : security_text(hint, 'Component hint')
      @security_components << SecurityComponent.new(id: clean_id, label: clean_label, hint: clean_hint)
    end

    def permission(component, role, label = SECURITY_UNSET, level: SECURITY_UNSET,
                   note: SECURITY_UNSET, focal: false, **options)
      raise Error, 'permission is available only in a DP security matrix' unless type == :dp_security_matrix
      raise Error, "Unknown security-matrix permission options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'focal must be true or false' unless [true, false].include?(focal)
      candidate = level.equal?(SECURITY_UNSET) ? nil : level.to_s.to_sym
      unless LEVELS.include?(candidate)
        raise Error, "Permission level must be one of #{LEVELS.join(', ')}"
      end
      if !note.equal?(SECURITY_UNSET) && !focal
        raise Error, 'A permission note is allowed only on a focal permission'
      end
      clean_component = security_text(component, 'Permission component ID')
      clean_role = security_text(role, 'Permission role ID')
      coordinate = [clean_component, clean_role]
      if @security_permissions.any? { |item| [item.component, item.role] == coordinate }
        raise Error, "Duplicate permission for component #{clean_component} and role #{clean_role}"
      end
      clean_label = label.equal?(SECURITY_UNSET) ? LEVEL_LABELS.fetch(candidate) : security_text(label, 'Permission label')
      clean_note = note.equal?(SECURITY_UNSET) ? nil : security_text(note, 'Permission note')
      @security_permissions << SecurityPermission.new(
        component: clean_component, role: clean_role, label: clean_label,
        level: candidate, note: clean_note, focal: focal
      )
    rescue NoMethodError
      raise Error, "Permission level must be one of #{LEVELS.join(', ')}"
    end

    def node(...)
      raise Error, 'DP security matrices use dedicated matrix records' if type == :dp_security_matrix
      super
    end

    def edge(...)
      raise Error, 'DP security matrices have no connectors' if type == :dp_security_matrix
      super
    end

    def connect(...)
      raise Error, 'DP security matrices have no connectors' if type == :dp_security_matrix
      super
    end

    private

    def security_identity(id, label, kind)
      clean_id = security_text(id, "#{kind} ID")
      [clean_id, security_text(label, "#{kind} label")]
    end

    def security_text(value, name)
      raise Error, "#{name} must be a String or Symbol" unless value.is_a?(String) || value.is_a?(Symbol)
      clean = Text.clean(value)
      raise Error, "#{name} is required and must not be blank" if clean.strip.empty?
      clean
    end

    def validate_dp_security_matrix!
      unless nodes.empty? && edges.empty? && groups.empty? && events.empty? && rules.empty? && states.empty? &&
             transitions.empty? && zones.empty? && phases.empty? && crosscuts.empty?
        raise Error, 'DP security matrices accept only dedicated matrix records'
      end
      raise Error, 'DP security matrices require two to five roles' unless security_roles.size.between?(2, 5)
      raise Error, 'DP security matrices require two to ten components' unless security_components.size.between?(2, 10)
      raise Error, 'Security-matrix role IDs must be unique' unless security_roles.map(&:id).uniq.size == security_roles.size
      unless security_components.map(&:id).uniq.size == security_components.size
        raise Error, 'Security-matrix component IDs must be unique'
      end
      expected = security_roles.size * security_components.size
      unless expected.between?(4, 36)
        raise Error, 'DP security matrices allow four to thirty-six permission cells'
      end
      role_ids = security_roles.map(&:id)
      component_ids = security_components.map(&:id)
      security_permissions.each do |item|
        raise Error, "Unknown security-matrix component: #{item.component}" unless component_ids.include?(item.component)
        raise Error, "Unknown security-matrix role: #{item.role}" unless role_ids.include?(item.role)
      end
      if security_permissions.count(&:focal) > 1
        raise Error, 'DP security matrices allow at most one focal permission'
      end
      missing = security_components.product(security_roles).find do |component, role|
        security_permissions.none? { |item| item.component == component.id && item.role == role.id }
      end
      if missing
        raise Error, "Missing explicit permission for component #{missing[0].id} and role #{missing[1].id}; declare deny or unknown explicitly"
      end
      if security_permissions.size != expected
        raise Error, 'DP security matrices require exactly one explicit permission for every component and role'
      end
      [security_roles, security_components, security_permissions].each do |records|
        records.each(&:freeze)
        records.freeze
      end
    end
  end
end

SlimGraphR::Diagram.prepend(SlimGraphR::DPSecurityMatrixDSL)
