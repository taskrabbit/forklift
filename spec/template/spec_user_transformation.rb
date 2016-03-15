class SpecUserTransformation

  def do!(connection, forklift, args)
    connection.q("ALTER TABLE `users` ADD `full_name` VARCHAR(255)  NULL  DEFAULT NULL  AFTER `updated_at`;")
    connection.q("UPDATE `users` SET full_name = CONCAT('#{args[:prefix]}', ' ', first_name, ' ', last_name);")
  end

end