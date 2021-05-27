1. � ����� ������� ������ ������ ���������?

������: � ������� airports ������ ����������� �� ������ (city)
� �������� ��������, ��� ���������� ����� ������ �����.

select 	 city 
from 	 airports 
group by city
having 	 count(*) > 1

2. � ����� ���������� ���� �����, ����������� ���������
� ������������ ���������� ��������?

������: � ���������� � ������� aircraft ������� ������������ �������� 
������������ ��������� ������ (range) � ����� � ��� ����� ���������� 
� ������� aircraft �������� ��� �������� (aircraft_code),
��������������� ����������� ������������� ��������. 
�� ������� flights �������� �����, ��������������� ����������� 
� ���������� ���� ��������. ��� ������ inner join ����������� 
�� ������� airports �������� ���������� (airport_name).

select 	 f.departure_airport as airport,
		 a.airport_name
from 	 flights f
	 	 inner join airports a on f.departure_airport = a.airport_code 
where 	 aircraft_code = (
					  	 select aircraft_code
					  	 from aircrafts 
					  	 where range = (select max(range) from aircrafts)
					  	 )
group by f.departure_airport,
		 a.airport_name

3. ������� 10 ������ � ������������ �������� �������� ������.

������: �������� ������ ����� ��������� ������ �� ��� ������, 
������� ��� ��������, ������� �������� �� ������� flights �� ������, 
��� ������� ����������� ����� ������ (actual_departure). 
��������� �� �������� �� ������� �������� (actual_departure � 
scheduled_departure) � ��������� 10 ������� �����.

select 	 flight_no,
		 scheduled_departure,
		 actual_departure,
		 actual_departure - scheduled_departure as delay
from 	 flights f
where 	 actual_departure is not null
order by actual_departure - scheduled_departure  desc
limit 	 10

4. ���� �� �����, �� ������� �� ���� �������� ���������� ������?

������: ������, ��� ��� �������, �������� ������ ��� ��� ������, 
������� ��������� � ������� ��� ��� �������, ��� ������ � ���������� ���������
��������, ��� ���������� ������ ���� ��� �� ��������. ������� � ���������� 
�������� �� ������� flights �������������� ������ (flight_id) �� �������� 
�Departed� � �Arrived�.
� ������� tickets ����� left join ������������ ������� boarding_passes.
�������� �� ������, ��� ������� � boarding_passes �� �������� ������������ 
(boarding_no is null) � �������������� ������ ������� ������������ � ����������.
��� ������ case ������� �����: ���� ���������� ����� � �������������� ������� 
�������� ������ ����, ������� ����� �����, � ��������� ������ ��� ����.

select 	 case 
		 	when count(distinct book_ref) > 0 then '����'
		 	else '�� ����' 
		 end as answer
from 	 tickets t 
	 	 left join boarding_passes bp on t.ticket_no = bp.ticket_no
where 	 boarding_no is null
		 and flight_id in (
						  select flight_id
						  from flights
						  where status in ('Departed', 'Arrived')
						  )

5. ������� ��������� ����� ��� ������� �����, �� % ��������� � ������ ����������
���� � ��������.
�������� ������� � ������������� ������ - ��������� ���������� ����������
���������� ���������� �� ������� ��������� �� ������ ����. �.�. � ���� ������� 
������ ���������� ������������� ����� - ������� ������� ��� �������� �� �������
��������� �� ���� ��� ����� ������ ������ �� ����.

������: 5.	� ���������� �c� ������ ����������� �� ���� �������� (aircraft_code)
� ������� seats � ������� ����� ���������� ���� � �������� (capacity).
� ���������� �o� ������ ����������� �� �������������� ����� (flight_id) 
� ������� boarding_passes � ������� ���������� ������� ���� (occupancy)
�� ������ �����.
���������� ������� flights ��� ������ inner join � �������� airports, ����������
�������� ����������. ���������� ����� � ����� ������������, ��� ����������� 
� �o� ��� ���� ���������� left join, �.�. ������ �������� ������ �������.
������ ������ ����� ����� ������ ��� ������������ ������, ������� � where 
�������� �� �����, � ������� ������� ����������� ����� ������ (actual_departure). 
��������� ���������� ��������� ���� (avs_num), ������� �� ������ ���������� ����
� �������� (capacity) ���������� ������� (occupancy). ��������� ������� 
��������� ����, �������� ���������� ��������� ���� �� ����� ���������� ���� 
� �������� � ������� �� 100.
��� �������� ������������ ����� �� ���������� ���������� ���������� ������� 
����� �� ���� � ��������� �� ������ �� ����������� ���� ����������� � ���������
�����������, � ����� � ����������� �� ������������ ������� �����������.

select  f.flight_id,
		f.actual_departure,
		concat(airport_name , ' (', f.departure_airport, ')') as airport,
		c.capacity - coalesce(o.occupancy, 0) as avs_num, -- ���-�� ��������� ����
  		concat(
  			round(
  			(c.capacity - coalesce(o.occupancy, 0))
  			/ c.capacity :: numeric * 100), 
    		'%') as avs_perc, -- ������� ��������� ����
  		sum(
		    coalesce(o.occupancy, 0)) over (
		    	partition by date(f.actual_departure), departure_airport 
		    	order by actual_departure
		   ) as ctp -- ����������� ���� �� ���-�� ���������� ����������
from 	 flights f
		 inner join airports a on f.departure_airport = a.airport_code
		 inner join (
					select aircraft_code, count(*) as capacity
					from seats
					group by aircraft_code
					) c on f.aircraft_code = c.aircraft_code
		 left join 	(
					select flight_id, count(*) as occupancy
					from boarding_passes
					group by flight_id
					) o on f.flight_id = o.flight_id
where 	 actual_departure is not null
order by airport,
		 actual_departure

6. ������� ���������� ����������� ��������� �� ����� ��������� �� ������ 
����������.

������: � ���������� ������� ����� ���������� ������ � ������� flights.
� ������� flights ������ ����������� �� ���� �������� (aircraft_code), 
������� ���������� ������ � ������ ����� � ����� �� ����� ���������� ������,
����������� � ����������. ��� ����, ����� �������� �� ����� ����� ��������, 
�������� �� 100.
��� ������ inner join ����������� �� ������� aircrafts ������ �������� (model).

select 	 a.model,
		 concat(
		 	round(
		 	count(*)::numeric / (select count(*) from flights) * 100,
		 	2), '%') as "share"
from 	 flights f
		 inner join aircrafts a on f.aircraft_code = a.aircraft_code
group by a.aircraft_code
order by count(*)::numeric / (select count(*) from flights) desc
		
7. ���� �� ������, � ������� �����  ��������� ������-������� �������, 
��� ������-������� � ������ ��������?

������: � ���������� �e� �������� ������, ��������������� ������-������,
�� ������� ticket_flights, ������ ����������� �� �������������� �����
(flight_id) � ������� ������������ �������� ������ ������ ��� ������� �����. 
� ���������� �b� �������� ������, ��������������� ������-������, 
�� ������� ticket_flights, ������ ����������� �� �������������� �����
(flight_id) � ������� ����������� �������� ������ ������ ��� ������� �����. 
������� flights ���������� � ����� ������������, � ����� ������ � �������� 
airports, �������� ������ ������, ����� ��������� �������� �������.
������ ������� � ��������, ����� ����������� ���� �� ������ ������ (b.price) 
���� ������, ��� ������������ ���� �� ������ ������ (e.price).
� ������� ans �������� ���������� �� ������: �������������, ����� � ��������
����������� � ����������. ���������� ��������� ��������� � CTE comparison.
������� ��������� �t�, ������� ��� ������� ������������� ���� �� ����� ������ 
� comparison ����� �������� 1, � ��������� ������ 0. ���������� comparison 
����� left join � �����������  �t� ��� ������� t.case > 0, �.�. ������ � ��� 
������, ����� � comparison ���� ���� �� ���� ������. ����� case ������� �������
������ ����������: � ������, ����� � comparison ��� �� ����� ������, �������� 
����� ��� ����, � ��������� ������ �������� ������� ans �� comparison.

with comparison as
(select  f.flight_id,
		 e.price as economy,
		 b.price as business,
		 concat('flight_id �', f.flight_id::text, ' - ���� � �. ', 
		 	arrival.city, ' (', arrival.airport_code, ')',
		 	' �� �. ', departure.city, ' (', departure.airport_code, ')') as ans
from 	 flights f
		 inner join (
		 			select 	 flight_id, max(amount) as price
					from 	 ticket_flights
					where 	 fare_conditions = 'Economy'
					group by flight_id
					) e on f.flight_id = e.flight_id
		 inner join (
					select flight_id, min(amount) as price
					from ticket_flights
					where fare_conditions = 'Business'
					group by flight_id
					) b on f.flight_id = b.flight_id
		 inner join airports departure on f.departure_airport = departure.airport_code
		 inner join airports arrival on f.arrival_airport = arrival.airport_code
where 	 b.price < e.price)
select 	 case 
		 	when t.case = 0 then '�� ����'
		 	else ans
	     end
from 	 ( 
	 	 select
		 case 
			when exists(select * from comparison) then 1 
			else 0
		 end
		 ) t
		 left join comparison on t.case > 0

8. ����� ������ �������� ��� ������ ������?

������: ��� ����, ����� ��������� �������� ������� (city) ����������� � 
���������� ������ ��������� ������� flights � �������� airports, ���������� 
������ ������.
��� ��������� ���������� �������� ������ ����������� �� ������ ����������� � 
������ ����������.
� ���������� �������� ������, ����� �������� ���������� ������ �����,
���������� ��������� ��������� � ����������������� ������������� routes_cities.
��� ��������� ���� ��������� ��������� ������� ���� � ������ ������ 
cross join ������� airports � ��� �����.
��� ������ ������� where a1.city < a2.city ����������� �� ������������ 
��������� �������.
��������� ������, ����� �������� ���� ������ ����� (except ������ �� 
routes_cities).

create materialized view routes_cities as
	select   departure.city as dep_city,
		 	 arrival.city as arv_city
	from 	 flights f
			 inner join airports departure on f.departure_airport = departure.airport_code
			 inner join airports arrival on f.arrival_airport = arrival.airport_code
	group by departure.city, arrival.city
with data

select  a1.city,
		a2.city 
from 	airports a1
		cross join airports a2
where 	a1.city < a2.city
except
select 	dep_city,
		arv_city
from 	routes_cities

9. ��������� ���������� ����� �����������, ���������� ������� �������, 
�������� � ���������� ������������ ���������� ���������  � ���������, 
������������� ��� �����.

������: ������ ������� �� ������ ����� �� ������� flights, ��� ������ 
inner join �����������  �� ������� aircrafts ������������ ��������� ������.
������ �������� � �������� airports � ���������� ������ ������, ����������� 
�������� ���������, �����, ������� � ������ ��� ���������� ����������� � 
����������. ���������� �� ������ �����, ���� ��������, ���� ��������� 
����������� � ���� ��������� ��������, ����� �������� ���������� ��������. 
���������� ������ ���������� � ����������������� ������������� 
routes_coordinates.
� CTE comparison, ��������� ������ �� ������������� routes_coordinates, 
��������� ���������� ���������� ����� �������� (actual_distance) �� �������
����� ����������.
����� � ������� ���������� ��� ���������� � ������������ ���������� ������ 
(max_distance).

create materialized view routes_coordinates as
select 	 f.flight_no,
		 a."range" as max_distance,
		 departure.airport_code as dep_airport_code,
		 departure.airport_name as dep_airport_name,
		 departure.city as dep_city,
		 departure.latitude as dep_latitude,
		 departure.longitude as dep_longitude, 
		 arrival.airport_code as arv_airport_code,
		 arrival.airport_name as arv_airport_name,
		 arrival.city as arv_city,
		 arrival.latitude as arv_latitude,
		 arrival.longitude as arv_longitude
from 	 flights f
		 inner join aircrafts a on f.aircraft_code = a.aircraft_code
		 inner join airports departure on f.departure_airport = departure.airport_code
		 inner join airports arrival on f.arrival_airport = arrival.airport_code
group by f.flight_no,
		 a.aircraft_code,
		 departure.airport_code,
		 arrival.airport_code
with data

with comparison as
(select flight_no,
		concat(dep_city, ' (', dep_airport_code, ')') as departure,
		concat(arv_city, ' (', arv_airport_code, ')') as arrival,
		max_distance,
		ceil(acos(sind(dep_latitude) * sind(arv_latitude) + 
			cosd(dep_latitude) * cosd(arv_latitude) * cosd(dep_longitude - arv_longitude)
			) * 6371) as actual_distance
from 	routes_coordinates)
select 	*
from 	comparison
where 	actual_distance >= max_distance
