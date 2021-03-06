module Messages::Actions::MuteUnmute


  def mute_unmute(args)
    names = munge_list(args['pattern_names'])
    patterns = Pattern.where(:name => names)
    synths = Synth.where(:name => names)
    things = patterns + synths

    return pattern_not_found(names) if things.none?

    things.each do |thing|
      thing.update_attribute(:muted,args['mode'] == 'mute')
    end

    return {
      response: 'success',
      display: I18n.t(
        "actions.mute_unmute.success.#{(things.count) > 1 ? 'other' : 'one'}",
        names: names.to_sentence(
          last_word_connector: ' and '
        ),
        action: I18n.t("actions.mute_unmute.#{args['mode']}")
      )
    }
  end

end
