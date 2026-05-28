USE major_league_baseball;

-- PART I: SCHOOL ANALYSIS
-- 1. View the schools and school details tables

SELECT * FROM schools;
SELECT * FROM school_details;

-- 2. In each decade, how many schools were there that produced players?

SELECT FLOOR(yearID/10)*10 AS decade, COUNT(DISTINCT schoolID) AS no_of_schools 
FROM schools 
GROUP BY decade
ORDER BY decade;

-- 3. What are the names of the top 5 schools that produced the most players?

WITH school_CTE AS (
    SELECT schoolID, COUNT(DISTINCT playerID) AS no_of_players 
    FROM schools 
    GROUP BY schoolID
)
SELECT s.name_full, school_CTE.no_of_players 
FROM school_CTE 
LEFT JOIN school_details s ON s.schoolID = school_CTE.schoolID 
ORDER BY no_of_players DESC 
LIMIT 5;

-- 4. For each decade, what were the names of the top 3 schools that produced the most players?

WITH ds AS (
    SELECT FLOOR(s.yearID/10)*10 AS decade, sd.name_full, COUNT(DISTINCT s.playerID) AS no_of_players 
    FROM schools s 
    LEFT JOIN school_details sd ON s.schoolID = sd.schoolID
    GROUP BY decade, s.schoolID
),
final_CTE AS (
    SELECT *, ROW_NUMBER() OVER(PARTITION BY decade ORDER BY no_of_players DESC) AS school_ranking 
    FROM ds
)
SELECT decade, name_full AS university, no_of_players 
FROM final_CTE 
WHERE school_ranking <= 3
ORDER BY decade DESC, school_ranking;

-- PART II: SALARY ANALYSIS
-- 1. View the salaries table

SELECT * FROM salaries;

-- 2. Return the top 20% of teams in terms of average annual spending

SELECT teamID, yearID, SUM(salary) AS annual_spending
FROM salaries 
GROUP BY teamID, yearID;

WITH spending AS (
    SELECT teamID, yearID, SUM(salary) AS annual_spending
    FROM salaries 
    GROUP BY teamID, yearID 
    ORDER BY teamID, yearID
),
final_CTE AS (
    SELECT teamID, AVG(annual_spending) AS avg_spend,
           NTILE(5) OVER(ORDER BY AVG(annual_spending) DESC) AS spent_percent
    FROM spending 
    GROUP BY teamID
)
SELECT teamID, ROUND(avg_spend/1000000, 2) AS avg_spent_in_M 
FROM final_CTE 
WHERE spent_percent = 1;

-- 3. For each team, show the cumulative sum of spending over the years

WITH CTE AS (
    SELECT yearID, teamID, SUM(salary) AS total_spent_by_yr 
    FROM salaries 
    GROUP BY yearID, teamID 
    ORDER BY total_spent_by_yr
)
SELECT *, ROUND(SUM(total_spent_by_yr) OVER(PARTITION BY teamID ORDER BY yearID)/1000000, 1) AS cumsum_of_spent_in_M 
FROM CTE;

-- 4. Return the first year that each team's cumulative spending surpassed 1 billion

WITH CTE AS (
    SELECT yearID, teamID, SUM(salary) AS total_spent_by_yr 
    FROM salaries 
    GROUP BY teamID, yearID 
    ORDER BY yearID, teamID
),
cm AS (
    SELECT *, SUM(total_spent_by_yr) OVER(PARTITION BY teamID ORDER BY yearID) AS cumsum_in_M 
    FROM CTE
),
final AS (
    SELECT *, ROW_NUMBER() OVER(PARTITION BY teamID ORDER BY cumsum_in_M) AS row_num
    FROM cm 
    WHERE cumsum_in_M > 1000000000
)
SELECT yearID, teamID, cumsum_in_M 
FROM final 
WHERE row_num = 1;

-- PART III: PLAYER CAREER ANALYSIS
-- 1. View the players table and find the number of players in the table

SELECT * FROM players;
SELECT DISTINCT COUNT(playerID) AS no_of_players FROM players;

-- 2. For each player, calculate their age at their first game, their last game,
-- and their career length (all in years). Sort from longest career to shortest career.

SELECT playerID, nameGiven,
       CONCAT(birthYear, "-", birthMonth, "-", birthDay) AS birthdate,
       debut, finalGame,
       TIMESTAMPDIFF(YEAR, CONCAT(birthYear, "-", birthMonth, "-", birthDay), debut) AS debut_age,
       TIMESTAMPDIFF(YEAR, CONCAT(birthYear, "-", birthMonth, "-", birthDay), finalGame) AS finalGame_age,
       TIMESTAMPDIFF(YEAR, debut, finalGame) AS career_length
FROM players 
ORDER BY career_length DESC;

-- 3. What team did each player play on for their starting and ending years?

SELECT p.nameGiven,
       s.yearID AS starting_year, s.teamID AS starting_team,
       e.yearID AS ending_year,   e.teamID AS ending_team
FROM players p
INNER JOIN salaries s ON p.playerID = s.playerID AND YEAR(p.debut)     = s.yearID
INNER JOIN salaries e ON p.playerID = e.playerID AND YEAR(p.finalGame) = e.yearID;

-- 4. How many players started and ended on the same team and also played for over a decade?

WITH CTE AS (
    SELECT p.nameGiven,
           s.yearID AS starting_year, s.teamID AS starting_team,
           e.yearID AS ending_year,   e.teamID AS ending_team
    FROM players p
    INNER JOIN salaries s ON p.playerID = s.playerID AND YEAR(p.debut)     = s.yearID
    INNER JOIN salaries e ON p.playerID = e.playerID AND YEAR(p.finalGame) = e.yearID
)
SELECT * FROM CTE 
WHERE starting_team = ending_team
  AND ending_year - starting_year > 10;

-- PART IV: PLAYER COMPARISON ANALYSIS
-- 1. View the players table

SELECT * FROM players;

-- 2. Which players have the same birthday?

WITH CTE AS (
    SELECT CAST(CONCAT(birthYear, "-", birthMonth, "-", birthDay) AS DATE) AS birthdate, nameGiven 
    FROM players
),
BD AS (
    SELECT * FROM CTE 
    WHERE birthdate IS NOT NULL 
      AND YEAR(birthdate) BETWEEN 1980 AND 1990 
    ORDER BY birthdate
)
SELECT birthdate, GROUP_CONCAT(nameGiven SEPARATOR ", ") AS same_bdate, COUNT(*) AS num 
FROM BD
GROUP BY birthdate 
HAVING COUNT(*) > 2 
ORDER BY birthdate;

-- 3. Create a summary table that shows for each team,
--    what percent of players bat right, left and both

SELECT * FROM players;
SELECT DISTINCT bats FROM players;

SELECT s.teamID, COUNT(bats) AS total_players,
       ROUND(SUM(CASE WHEN bats = "R" THEN 1 ELSE 0 END) / COUNT(bats) * 100, 2) AS right_handed,
       ROUND(SUM(CASE WHEN bats = "L" THEN 1 ELSE 0 END) / COUNT(bats) * 100, 2) AS left_handed,
       ROUND(SUM(CASE WHEN bats = "B" THEN 1 ELSE 0 END) / COUNT(bats) * 100, 2) AS both_handed
FROM salaries s
LEFT JOIN players p ON s.playerID = p.playerID
GROUP BY teamID;

-- 4. How have average height and weight at debut game changed over the years, and
--    what's the decade-over-decade difference?

WITH hw AS (
    SELECT FLOOR(YEAR(debut)/10)*10 AS decade, AVG(height) AS avg_height, AVG(weight) AS avg_weight 
    FROM players
    GROUP BY decade 
    ORDER BY decade
)
SELECT *, 
       ROUND(avg_height - LAG(avg_height) OVER(ORDER BY decade), 1) AS height_diff,
       ROUND(avg_weight - LAG(avg_weight) OVER(ORDER BY decade), 1) AS weight_diff 
FROM hw
WHERE decade IS NOT NULL;