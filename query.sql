#To get started, I imported the two CSV files from Excel into MySQL.
#I ran the following queries to get an overview of the data:

select vuid, category, sum(seconds_viewed) as seconds_viewed, count(*) as duplicates from new_schema.plays group by 1,2 order by duplicates desc;

select category, count(distinct vuid) as num_viewers, sum(seconds_viewed) as seconds_viewed from new_schema.plays group by 1 order by num_viewers desc;

select vuid, device, count(session_id) as num_sessions from new_schema.sessions group by 1,2 order by num_sessions desc;

select device, count(distinct vuid) as num_views, count(distinct session_id) as num_sessions from new_schema.sessions group by 1;

select vuid, count(session_id) as num_sessions from new_schema.sessions group by 1 order by num_sessions desc;

#After learning that both data sources contained duplicates, I created two cleaned versions of the files:

#drop table new_schema.plays_cleaned;
create table new_schema.plays_cleaned as
(
	select vuid, category, seconds_viewed from new_schema.plays group by 1,2,3 
);  

#drop table new_schema.sessions_cleaned;
create table new_schema.sessions_cleaned as
(
	select vuid, session_id, device from new_schema.sessions group by 1,2,3 
); 

#Next, I joined the two tables on vuid to create a combined table.

drop table new_schema.combined;
create table new_schema.combined as
(
select a.vuid, a.category, B.device,
seconds_viewed,
num_sessions
from 
	(
select vuid, category, sum(seconds_viewed) as seconds_viewed from new_schema.plays_cleaned group by 1,2
) A

	inner join 
(select vuid, device, count(session_id) as num_sessions from new_schema.sessions_cleaned group by 1,2) B
	on a.vuid=b.vuid
);

#My next step was to rank the view_times:

create table new_schema.view_times_ranked as
(
	select 
	vuid,
	@rownum := @rownum + 1 AS rank,
	seconds_viewed
	FROM
	(
		select 
		vuid, device, 
		@rownum := 0,
		sum(seconds_viewed) as seconds_viewed
		from new_schema.combined
		where device='desktop'
		GROUP BY 1,2
	) AS A
	order by seconds_viewed
);   


select rank, seconds_viewed, z.max_rank
from new_schema.view_times_ranked A
join  (select max(rank) as max_rank from new_schema.view_times_ranked) Z
having rank=max_rank/2 or rank=cast((max_rank/2+.5)as SIGNED) or rank=cast((max_rank/2-0.5) as SIGNED);

#The output of that query was the median view_time of 45 seconds for desktop users without regard to category.

#To figure out the total viewing the top 10% of users accounted for, I recreated the above table new_schema.view_times_ranked without the filter on desktop users and ran the following code:

select sum(zz.seconds_viewed)/sum(a.seconds_viewed)
from new_schema.view_times_ranked as A

left join
	(
   	select rank, seconds_viewed, z.max_rank
	from new_schema.view_times_ranked A
	join  (select max(rank) as max_rank from new_schema.view_times_ranked) Z
	where cast(max_rank*0.9 as signed)<=rank
   	 ) as zz
on a.rank=zz.rank
;

#The result was that the top 10% of users account for 64.38% of all traffic.

#To answer the next question, I ran the script below, dropped the results into Excel and created a pivot table so I could view the data in a better format:

select device, category, count(vuid) as num_users, sum(seconds_viewed) as seconds_viewed from new_schema.combined group by 1,2;

#   Observations:
#	Category 1, 2, and 3 account for 56% of total view time
#	Category 1 accounts for 34% of the total
#	Desktop viewership dominates mobile viewership 87% to 13% respectively
#	Categories 9, 17, 18, 19, and 20 were viewed almost exclusively on desktops
#	The data suggest categories  18, 19, and 20 are not available on mobile
#	Categories 8 and 16 had the highest percent mobile viewership, at around 1/3 of total viewership

#To answer the next question about segmentation, there are a number of questions to think through. One option is to define light/medium/heavy viewers on their distance away from the median view time. Medium users can be defined as falling one standard deviation above or below the median. Light users would account for all users below one standard deviation away from the median. The same would apply for heavy users in the other direction. I would recommend doing this for both desktop and mobile users. 

#For number of categories viewed, I would define light users as viewing a single category, medium users as 2-3 categories, and heavy users as 4 or more categories based on the data below:

/*
Number of Categories	Number of Accounts
17	1
15	1
14	4
13	1
12	9
11	13
10	13
9	37
8	49
7	73
6	130
5	217
4	351
3	678
2	1880
1	10185
*/
#Data above was generated from this code:

select num_categories, count(distinct vuid) as num_users
from
(
	select vuid, count(distinct category) as num_categories
	from new_schema.plays_cleaned group by 1
) as zz    
group by 1
order by 1 desc;