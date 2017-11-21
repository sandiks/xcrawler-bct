-- MySQL dump 10.16  Distrib 10.1.28-MariaDB, for Linux (x86_64)
--
-- Host: localhost    Database: bittalk
-- ------------------------------------------------------
-- Server version	10.1.28-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `bct_bounty`
--

DROP TABLE IF EXISTS `bct_bounty`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bct_bounty` (
  `name` tinytext COLLATE utf8_unicode_ci NOT NULL,
  `url` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL,
  `descr` varchar(1000) COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bct_post_marks`
--

DROP TABLE IF EXISTS `bct_post_marks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bct_post_marks` (
  `fid` int(11) DEFAULT NULL,
  `tid` int(11) NOT NULL,
  `mid` int(11) NOT NULL,
  `uid` int(11) DEFAULT NULL,
  `mark` int(11) DEFAULT NULL,
  `descr` tinytext,
  `updated_at` datetime DEFAULT NULL,
  KEY `tid_mid` (`tid`,`mid`,`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bct_user_bounty`
--

DROP TABLE IF EXISTS `bct_user_bounty`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bct_user_bounty` (
  `uid` int(11) DEFAULT NULL,
  `bo_name` tinytext COLLATE utf8_unicode_ci,
  `created_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `forums`
--

DROP TABLE IF EXISTS `forums`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `forums` (
  `siteid` int(11) NOT NULL,
  `fid` int(11) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `level` int(11) DEFAULT NULL,
  `parent_fid` int(11) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `check` int(11) DEFAULT NULL,
  `bot_updated` datetime DEFAULT NULL,
  `descr` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`siteid`,`fid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `forums_stat`
--

DROP TABLE IF EXISTS `forums_stat`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `forums_stat` (
  `sid` int(11) DEFAULT NULL,
  `fid` int(11) DEFAULT NULL,
  `bot_action` tinytext,
  `bot_parsed` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `logs`
--

DROP TABLE IF EXISTS `logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `logs` (
  `referer` varchar(255) DEFAULT NULL,
  `path` varchar(255) DEFAULT NULL,
  `ip` varchar(255) DEFAULT NULL,
  `uagent` varchar(255) DEFAULT NULL,
  `date` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `main_forums`
--

DROP TABLE IF EXISTS `main_forums`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `main_forums` (
  `mfid` int(11) NOT NULL,
  `title` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`mfid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `posts`
--

DROP TABLE IF EXISTS `posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `posts` (
  `mid` int(11) NOT NULL,
  `siteid` int(11) NOT NULL,
  `body` mediumtext,
  `addedby` varchar(50) DEFAULT NULL,
  `addeduid` int(11) DEFAULT NULL,
  `addedrank` tinyint(4) DEFAULT NULL,
  `activity` tinyint(4) DEFAULT NULL,
  `addeddate` datetime DEFAULT NULL,
  `tid` int(11) NOT NULL,
  `first` int(11) DEFAULT '0',
  `title` varchar(255) DEFAULT NULL,
  `marks` varchar(255) DEFAULT NULL,
  `pnum` int(11) DEFAULT NULL,
  PRIMARY KEY (`mid`,`siteid`,`tid`),
  KEY `indx_posts_sid_tid` (`siteid`,`tid`),
  KEY `posts_addeddate_indx` (`addeddate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `site_forums`
--

DROP TABLE IF EXISTS `site_forums`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `site_forums` (
  `mfid` int(11) NOT NULL,
  `siteid` int(11) NOT NULL,
  `fid` int(11) NOT NULL,
  PRIMARY KEY (`mfid`,`siteid`,`fid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sites`
--

DROP TABLE IF EXISTS `sites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sites` (
  `id` int(11) NOT NULL,
  `descr` char(100) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `threads`
--

DROP TABLE IF EXISTS `threads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `threads` (
  `tid` int(11) NOT NULL,
  `siteid` int(11) NOT NULL,
  `fid` int(11) NOT NULL,
  `title` text NOT NULL,
  `created` datetime DEFAULT NULL,
  `updated` datetime DEFAULT NULL,
  `viewers` int(11) DEFAULT NULL,
  `responses` int(11) DEFAULT NULL,
  `descr` char(100) DEFAULT NULL,
  `bot_updated` datetime DEFAULT NULL,
  `sticked` int(11) DEFAULT NULL,
  `bot_tracked` int(11) DEFAULT NULL,
  `last_viewed` datetime DEFAULT NULL,
  PRIMARY KEY (`tid`,`siteid`,`fid`),
  KEY `indx_threads_sid_fid_tid` (`fid`,`siteid`,`tid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `threads_responses`
--

DROP TABLE IF EXISTS `threads_responses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `threads_responses` (
  `sid` int(11) DEFAULT NULL,
  `fid` int(11) DEFAULT NULL,
  `tid` int(11) DEFAULT NULL,
  `responses` int(11) DEFAULT NULL,
  `last_post_date` datetime DEFAULT NULL,
  `parsed_at` datetime DEFAULT NULL,
  KEY `idnx_fid_stat_threads` (`fid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `threads_stat`
--

DROP TABLE IF EXISTS `threads_stat`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `threads_stat` (
  `fid` int(11) DEFAULT NULL,
  `tid` int(11) DEFAULT NULL,
  `added` datetime DEFAULT NULL,
  `start_date` datetime DEFAULT NULL,
  `end_date` datetime DEFAULT NULL,
  `last_page` smallint(6) DEFAULT NULL,
  `description` tinytext COLLATE utf8mb4_unicode_ci,
  `r1_count` smallint(6) DEFAULT NULL,
  `r2_count` smallint(6) DEFAULT NULL,
  `r3_count` smallint(6) DEFAULT NULL,
  `r4_count` smallint(6) DEFAULT NULL,
  `r5_count` smallint(6) DEFAULT NULL,
  `r11_count` smallint(6) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tpages`
--

DROP TABLE IF EXISTS `tpages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tpages` (
  `siteid` int(11) NOT NULL,
  `tid` int(11) NOT NULL,
  `page` int(11) NOT NULL,
  `postcount` int(11) DEFAULT NULL,
  `fp_date` datetime DEFAULT NULL,
  PRIMARY KEY (`siteid`,`tid`,`page`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `name` varchar(50) NOT NULL,
  `uid` int(11) DEFAULT NULL,
  `lastposted` datetime DEFAULT NULL,
  `siteid` int(11) NOT NULL,
  `rank` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`name`,`siteid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2017-11-21 19:39:41
