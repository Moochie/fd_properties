-- Dumping database structure for drp
CREATE DATABASE IF NOT EXISTS `drp` /*!40100 DEFAULT CHARACTER SET utf8mb4 */;
USE `drp`;

-- Dumping structure for table drp.owned_properties
CREATE TABLE IF NOT EXISTS `owned_properties` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `key` int(11) NOT NULL,
  `char_id` int(11) NOT NULL,
  `keys` varchar(50) NOT NULL DEFAULT '{}',
  `stash` varchar(255) NOT NULL DEFAULT '{}',
  `mortgage_payments` int(11) NOT NULL DEFAULT 0,
  `mortgage_amount` int(11) NOT NULL DEFAULT 0,
  `last_payment` int(11) DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `Index 2` (`char_id`)
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8mb4;