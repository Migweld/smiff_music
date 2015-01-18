class Synth < ActiveRecord::Base


  validate :name, presence: true
  validate :osc_type,
           presence: true,
           inclusion: %w{sine square saw triangle}
  validate :attack_time, numericality: {greater_than: 0, less_than: 2}
  validate :decay_time, numericality: {greater_than: 0, less_than: 2}
  validate :sustain_level, numericality: {greater_than: 0, less_than: 1}
  validate :release_time, numericality: {greater_than: 0, less_than: 5}

  after_create :generate_patterns

  serialize :pitches

  has_many :patterns do

    def note_on
      where(purpose: 'note_on').first
    end

    def note_off
      where(purpose: 'note_off').first
    end

  end

  def pitches
    super || self.pitches = Array.new(self.step_count)
  end

  after_save :modify_pattern_store

  def modify_pattern_store
    PatternStore.modify_hash(self)
  end

  def Synth.build_seeds
    definitions = YAML.load_file(File.join(Rails.root, 'db', 'seed', 'synths.yml'))
    definitions.each do |name, params|
      if Synth.where(name: name).any?
        Synth.where(name: name).first.update_attributes(params)
      else
        Synth.create!(params)
      end
    end
  end

  def generate_patterns
    unless self.patterns.note_on
      self.patterns.create!(
        muted: false,
        active:  true,
        purpose: 'note_on',
        name: "#{self.name}_note_on",
        step_count: step_count,
        step_size: step_size
      )
    end
    unless self.patterns.note_off
      self.patterns.create!(
        muted: false,
        active: true,
        purpose: 'note_off',
        name: "#{self.name}_note_off",
        step_count: step_count,
        step_size: step_size
      )
    end
  end


  def Synth.sound_init_params
    hash = {:synths => {}}
    all.each do |synth|
      hash[:synths][synth.name] = synth.sound_init_params
    end
    hash
  end

  def sound_init_params
    {
      osc_type: osc_type,
      attack_time: attack_time,
      decay_time: decay_time,
      sustain_level: sustain_level,
      release_time: release_time,
      muted: muted,
      note_on_steps: patterns.note_on.bits,
      note_off_steps: patterns.note_off.bits,
      step_count: step_count,
      pitches: pitches
    }
  end

  def Synth.to_hash
    result = {}
    all.each do |synth|
      result[synth.name] = synth.to_hash
    end
    result
  end

  def to_hash
    {
      muted: muted,
      note_on_steps: patterns.note_on.bits,
      note_off_steps: patterns.note_off.bits,
      pitches: pitches
    }
  end

end
