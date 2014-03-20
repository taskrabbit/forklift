class EmailSuffix

  def do!(connection, forklift)
    forklift.logger.log "collecting email suffixes..."
    
    suffixes = {}
    connection.read("select email from users"){|data| 
      data.each do |row|
        part = row[:email].split('@').last
        suffixes[part] = 0 if suffixes[part].nil?
        suffixes[part] = suffixes[part] + 1
      end
    }

    suffixes.each do |suffix, count|
      forklift.logger.log " > #{suffix}: #{count}" if count > 5
    end
  end

end