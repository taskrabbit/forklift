require 'terminal-table'

module Forklift 
  class Plan

    ###################
    # TEMPLATED EMAIL #
    ###################

    def templated_email(args)
      @plan[:templated_emails][:emails].push(args)
    end

    def send_templated_emails(emailer)
      @plan[:templated_emails][:emails].each do |templaed_email|
        variables = resolve_email_variables(templaed_email[:variables])
        emailer.send_template({
          :to => templaed_email[:to],
          :subject => templaed_email[:subject],
        }, templaed_email[:template], variables)
      end
    end

    def resolve_email_variables(variable_hash)
      resolved = {}
      variable_hash.each do |k,v|
        connection = @connections[:local_connection]
        connection.q("use `#{config.get(:final_database)}`")
        #TODO: Better SQL determiniation
        if(v.include?("select") || v.include?("SELECT"))
          rows = []
          connection.connection.query("#{v}").each do |row|
            rows << row
          end
          if rows.length == 0
            resolved[k] = "{no results}"
          elsif rows.length == 1 && rows[0].values.length == 1 # single value
            resolved[k] = rows[0].values[0]
          else # Table-ize
            value_rows = []
            rows.each do |row|
              value_rows << row.values
            end
            table = Terminal::Table.new({:rows => value_rows, :headings => rows.first.keys})
            table.align_column(1, :right)
            resolved[k] = table
          end
        else
          resolved[k] = v
        end
      end
      return resolved
    end

  end
end