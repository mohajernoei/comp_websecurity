-- Optional manual setup (setup_and_run.sh already creates this user automatically).

CREATE USER IF NOT EXISTS 'twitter_admin'@'localhost' IDENTIFIED BY 'MyAppPassw0rd!';

GRANT ALL PRIVILEGES ON `twitter_miniapp`.* TO 'twitter_admin'@'localhost';

FLUSH PRIVILEGES;

