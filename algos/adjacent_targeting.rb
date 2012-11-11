module BattleGroup
  #
  # Implements a random hunt with adjacent targeting.  The hunting
  # uses a parity (checkboard) based approach.  While targeting,
  # encountered a hit, all the adjacent cells are also checked.
  #
  # 63 shot average over 100 games
  #
  module AdjacentTargeting
    def next_coordinate
      @shot = next_target
    end

    def next_target
      (hunting? ? targets : focused_targets).shift
    end

    def assess(intel)
      shots << @shot
      refine_targeting if intel[:hit]
    end

    def refine_targeting
      shots.last.adjacent.each do |target|
        next if shots.include? target
        targets.delete(target) if targets.include? target
        focused_targets << target
      end
    end

    def targets
      @targets ||= coordinates.shuffle.shuffle
    end

    def coordinates
      10.times.collect do |col|
        rows = (0..9).select {|v| (col.odd? ? v.odd? : v.even?)}
        rows.map {|row| Coordinate.new(row, col)}
      end.flatten
    end

    def hunting?
      focused_targets.empty?
    end

    def attacking?
      !hunting?
    end

    def focused_targets
      @focused_targets ||= []
    end

    def shots
      @shots ||= []
    end
  end
end