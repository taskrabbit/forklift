module Forklift
  class CheckEvaluator

    def local(check, connection, logger)
      connection.q("USE #{check[:database]}")
      result = connection.q(check[:query])
      if Forklift::Debug.debug? == true
        logger.log "[local check] #{check[:name]} SKIPPED"
      elsif result.to_s == check[:expected].to_s
        logger.log "[local check] #{check[:name]} PASSED"
      else
        logger.fatal "[local check] #{check[:name]} FAILED"
      end
    end

    def remote(check, connection, logger)
      connection.q("USE #{check[:database]}")
      result = connection.q(check[:query])
      if Forklift::Debug.debug? == true
        logger.log "[local check] #{check[:name]} SKIPPED"
      elsif result.to_s == check[:expected].to_s
        logger.log "[remote check] #{check[:name]} PASSED"
      else
        logger.fatal "[remote check] #{check[:name]} FAILED"
      end
    end

  end
end