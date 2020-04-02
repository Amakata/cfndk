module CFnDK
  FORMAT = :unified
  LINES = 3

  def self.diff(data_old, data_new)
    result = ''

    file_length_difference = 0

    data_old = data_old.split($/).map { |e| e.chomp }
    data_new = data_new.split($/).map { |e| e.chomp }

    diffs = Diff::LCS.diff(data_old, data_new)
    diffs = nil if diffs.empty?

    return '' unless diffs

    oldhunk = hunk = nil

    diffs.each do |piece|
      begin
        hunk = Diff::LCS::Hunk.new(data_old, data_new, piece, LINES, file_length_difference)
        file_length_difference = hunk.file_length_difference

        next unless oldhunk
        next if LINES.positive? and hunk.merge(oldhunk)

        result << oldhunk.diff(FORMAT) << "\n"
      ensure
        oldhunk = hunk
      end
    end

    last = oldhunk.diff(FORMAT)
    last << "\n" if last.respond_to?(:end_with?) && !last.end_with?("\n")
    result << last
  end
end
