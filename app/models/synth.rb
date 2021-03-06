class Synth < ActiveRecord::Base

  validate :name, presence: true
  validate :waveshape,
           presence: true,
           inclusion: %w{sine square saw triangle}
  validate :attack_time, numericality: {greater_than: 0, less_than: 2}
  validate :decay_time, numericality: {greater_than: 0, less_than: 2}
  validate :sustain_level, numericality: {greater_than: 0, less_than: 1}
  validate :release_time, numericality: {greater_than: 0, less_than: 5}

  after_create :generate_patterns
  before_save :save_patterns

  store :parameters,
        accessors: [
          # for SimpleSynth synths
          :waveshape,
          # For FMSynth synths
          :fm_frequency, :fm_depth, :fm_waveshape,
          # For AMSynth synths
          :am_frequency, :am_depth, :am_waveshape,
          # for PolySynth synths
          :sine_level, :square_level,
          :sawtooth_level, :triangle_level,
          # for SubSynth synths
          :bandwidth,
          # for all synths
          :volume
        ],
        coder: JSON

  validates_numericality_of :volume,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100
  # For FMSynth synths
  validates_numericality_of :fm_frequency,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100,
                            if: lambda{self.constructor == 'FMSynth'}
  validates_numericality_of :fm_depth,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100,
                            if: lambda{self.constructor == 'FMSynth'}
  validates_presence_of :fm_waveshape,
                        in: ['sine','square','sawtooth','triangle'],
                        if: lambda{self.constructor == 'FMSynth'}

  # For AMSynth synths
  validates_numericality_of :am_frequency,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100,
                            if: lambda{self.constructor == 'AMSynth'}
  validates_numericality_of :am_depth,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100,
                            if: lambda{self.constructor == 'AMSynth'}
  validates_presence_of :am_waveshape,
                        in: ['sine','square','sawtooth','triangle'],
                        if: lambda{self.constructor == 'AMSynth'}

  # for PolySynth synths
  validates_numericality_of :sine_level,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100,
                            if: lambda{self.constructor == 'PolySynth'}
  validates_numericality_of :square_level,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100,
                            if: lambda{self.constructor == 'PolySynth'}
  validates_numericality_of :sawtooth_level,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100,
                            if: lambda{self.constructor == 'PolySynth'}
  validates_numericality_of :triangle_level,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100,
                            if: lambda{self.constructor == 'PolySynth'}

  # for SubSynth synths
  validates_numericality_of :bandwidth,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100,
                            if: lambda{self.constructor == 'SubSynth'}

  after_save :modify_pattern_store

  serialize :pitches

  has_many :patterns, dependent: :destroy do

    def note_on
      where(purpose: 'note_on').first
    end

    def note_off
      where(purpose: 'note_off').first
    end

  end

  cattr_accessor :types

  def Synth.types
    @@types ||= YAML.load_file(File.join(Rails.root, 'config', 'synth_types.yml'))
  end

  attr_accessor :type

  def type
    @type ||= Synth.types[constructor]
  end

  def description
    result = <<TEXT
'#{name}' is a #{type['name']} synthesizer.
#{type['description']}Parameters:
TEXT
    type['parameters'].each do |parameter|
      result << "* #{parameter['name']} - #{parameter['description']}"
    end
    result
  end

  def parameter_list
    result = ''
    type['parameters'].each do |parameter|
      result << "* #{parameter['name']} (#{self.send(parameter['name'])})\n"
    end
    result
  end

  def parameter_names
    parameters.keys
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

  def save_patterns
    note_on.save! if note_on
    note_off.save! if note_off
  end


  def note_on
    return @note_on if @note_on
    @note_on = patterns.note_on
  end

  def note_off
    return @note_off if @note_off
    @note_off = patterns.note_off
  end

  def modify_pattern_store
    PatternStore.modify_hash(self)
  end

  def generate_patterns
    unless self.patterns.note_on
      self.patterns.create!(
        muted: false,
        active: true,
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

  def pitches
    super || self.pitches = Array.new(self.step_count || 0)
  end

  def range
    (max_note - min_note) + 1
  end


  def pitch_at_step(step)
    pitches[0..step].compact.last
  end

  def active_at_step(step)
    note_on = patterns.note_on.pattern_bits
    note_off = patterns.note_off.pattern_bits
    active = nil
    return true if note_on[step]
    until active != nil or step < 0 do
      if note_off[step]
        active = false
      elsif note_on[step]
        active = true
      end
      step -= 1
    end
    active
  end


  def Synth.sound_init_params
    hash = {:synths => {}}
    all.each do |synth|
      hash[:synths][synth.name] = synth.sound_init_params
    end
    hash
  end

  def sound_init_params
    params = {
      waveshape: waveshape,
      attack_time: attack_time,
      decay_time: decay_time,
      sustain_level: sustain_level,
      release_time: release_time,
      muted: muted,
      note_on_steps: patterns.note_on.bits,
      note_off_steps: patterns.note_off.bits,
      step_count: step_count,
      pitches: pitches,
      name: name,
      constructor: constructor
    }
    params.merge!(self.parameters.symbolize_keys)
    params
  end

  def Synth.to_hash
    result = {}
    all.each do |synth|
      result[synth.name] = synth.to_hash
    end
    result
  end

  def to_hash
    params = {
      muted: muted,
      note_on_steps: patterns.note_on.bits,
      note_off_steps: patterns.note_off.bits,
      pitches: pitches
    }
    params.merge!(self.parameters.symbolize_keys)
    params
  end

  attr_accessor :chart_data

  def chart_data
    return @chart_data if @chart_data
    @chart_data = []
    envelope_times = [
      (attack_time * 1000).to_i,
      (decay_time * 1000).to_i,
      (release_time * 1000).to_i
    ]
    gcd = envelope_times.reduce(:gcd)

    @chart_data << 0
    (((attack_time * 1000) / gcd) - 1).to_i.times { @chart_data << nil }
    @chart_data << 1
    (((decay_time * 1000) / gcd) - 1).to_i.times { @chart_data << nil }
    @chart_data << sustain_level
    (((attack_time * 1000) + (decay_time * 1000)) / gcd).to_i.times { @chart_data << nil }
    @chart_data << sustain_level
    (((release_time * 1000) / gcd) - 1).to_i.times { @chart_data << nil }
    @chart_data << 0
    @chart_data
  end

  # This uses chart_data above to generate full params for the chart plugin
  def chart_data_full
    {
      labels: Array.new(chart_data.length, ''),
      datasets: [
        {
          fillColor: "rgba(220,220,220,0.2)",
          strokeColor: "rgba(220,220,220,1)",
          data: chart_data
        }
      ]
    }
  end

  def add_note(pitch, start_step, length)
    end_step = start_step + (length - 1)
    Synth.transaction do
      clear_range(start_step, end_step)
      pitches[start_step] = pitch
      note_on.pattern_indexes += [start_step]
      note_off.pattern_indexes += [end_step]
      save!
    end
  end

  def clear_pitch(midi_note)
    self.pitches.each_with_index do |pitch, index|
      if pitch == midi_note
        remove_note(index)
      end
    end
  end

  def remove_note(start_step)
    if active_at_step(start_step)
      pitch = pitches[start_step]
      until pitch or start_step < 0
        start_step -= 1
        pitch = pitches[start_step]
      end
      if pitch
        end_step = note_off.pattern_indexes.select { |x| x >= start_step }.sort[0]
        clear_range(start_step, end_step)
        save!
        true
      else
        nil
      end
    else
      nil
    end
  end



  def clear_range(start_step, end_step, skip_note_off = false)
    # add note_on and pitch if next step is active.
    if self.active_at_step(end_step + 1)
      note_on.pattern_indexes += [end_step + 1]
      pitches[end_step + 1] = pitch_at_step(end_step + 1)
    end
    # clear contents
    (start_step..end_step).each { |index| pitches[index] = nil }
    note_on.pattern_indexes -= (start_step..end_step).to_a
    note_off.pattern_indexes -= (start_step..end_step).to_a unless skip_note_off
    # add note_off if previous step is active.
    if self.active_at_step(start_step - 1) and start_step != 0
      note_off.pattern_indexes += [start_step - 1]
    end
  end

  def clear
    clear_range(0, (self.step_count - 1), true)
    save!
  end




end
