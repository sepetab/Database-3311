create or replace view Q1(pid, firstname, lastname) as
select pid, firstname, lastname
from person
where pid not in (
    (select c.pid from client c)
    UNION 
    (select s.pid from staff s)
)
order by pid;

create or replace view Q2(pid, firstname, lastname) as
select pid, firstname, lastname
from person
where pid not in (
    select c.pid from insured_by i 
    join client c on c.cid = i.cid
    join policy p on p.pno = i.pno
    where p.status = 'E'
) 
order by pid;

create or replace view q3h(brand,id,pno,premium) as
select distinct subq.brand,subq."item id",subq."policy number",sum(subq.rate) over (partition by subq."policy number") as premium
from (  
    select i.brand as "brand", p.id as "item id",p.pno as "policy number" , r.rate as "rate"
    from policy p 
    join coverage c on p.pno = c.pno 
    join rating_record r on c.coid = r.coid
    join underwriting_record u on p.pno = u.pno
    join insured_item i on p.id = i.id
    where p.status = 'E' and u.status = 'A' and r.status = 'A'
) as subq;


create or replace view Q3(brand, vid, pno, premium) as
select qh.brand,qh.id,qh.pno,qh.premium
from q3h as qh, 
(select qh.brand, max(qh.premium) as premium 
from q3h as qh
group by qh.brand) as sq
where sq.brand = qh.brand and sq.premium = qh.premium
order by qh.brand, qh.id, qh.pno;

create or replace view allStaffPno (sid, pno) as
select distinct setq.sid,setq.pno from 
(select urb.sid, urr.pno 
from underwritten_by urb 
join underwriting_record urr on urb.urid = urr.urid
union
select rb.sid, c.pno
from rated_by rb 
join rating_record rr on rr.rid = rb.rid
join coverage c on c.coid = rr.coid
union
select sid,pno 
from policy) as setq


create or replace view Q4(pid, firstname, lastname) as
select p.pid, p.firstname, p.lastname
from person p join (
    select pid from staff
    except
    select subq.sid from (
        select asp.sid,asp.pno from allStaffPno asp
        join policy p on p.pno = asp.pno
        where p.status = 'E'
        ) as subq
    ) res
on p.pid = res.pid
order by p.pid;

create or replace view Q5(suburb, npolicies) as
select upper(per.suburb), count(*) as "npolicies"
from insured_by i 
join policy p on p.pno = i.pno 
join client c on c.cid = i.cid 
join person per on per.pid = c.pid
where p.status = 'E'
group by per.suburb
order by npolicies, per.suburb;

create or replace view q6hr(sid,pno) as 
select distinct rb.sid, c.pno
from rated_by rb 
join rating_record rr on rr.rid = rb.rid
join coverage c on c.coid = rr.coid;


create or replace view q6hu(sid,pno) as 
select distinct urb.sid, urr.pno 
from underwritten_by urb 
join underwriting_record urr on urb.urid = urr.urid;

create or replace view q6hs(sid,pno) as 
select distinct sid,pno 
from policy;

create or replace view q6h (pno,sid) as 
SELECT distinct_rated_staff.pno, distinct_underwritten_staff.sid
FROM (select r.sid,r.pno from q6hr r where pno in (select pno from q6hr r group by pno having count(*) =1)) as distinct_rated_staff
JOIN (select u.sid,u.pno from q6hu u where pno in (select pno from q6hu u group by pno having count(*) =1)) as distinct_underwritten_staff
on distinct_rated_staff.pno = distinct_underwritten_staff.pno
JOIN (select s.sid,s.pno from q6hs s where pno in (select pno from q6hs s group by pno having count(*) =1)) as distinct_sold_staff
on distinct_rated_staff.pno = distinct_sold_staff.pno
where distinct_underwritten_staff.sid = distinct_rated_staff.sid and distinct_rated_staff.sid = distinct_sold_staff.sid;

create or replace view Q6(pno, ptype, pid, firstname, lastname) as
select q6h.pno, p.ptype, s.pid, per.firstname, per.lastname 
from q6h
join policy p on  p.pno = q6h.pno
join staff s on q6h.sid = s.sid
join person per on per.pid = s.pid
where p.status = 'E'
order by q6h.pno;


create or replace view q7rd(date, pno) as 
select distinct min(rb.rdate), c.pno 
from rated_by rb 
join rating_record rr on rr.rid = rb.rid 
join coverage c on c.coid = rr.coid
group by c.pno
order by c.pno;

create or replace view q7ud(date, pno) as
select distinct max(ub.wdate), ur.pno 
from underwritten_by ub 
join underwriting_record ur on ur.urid = ub.urid 
group by ur.pno
order by ur.pno;

create or replace view q7h(pno, days) as
select r.pno, (ur.date-r.date) as "diff"
from q7ud ur
join q7rd r on ur.pno = r.pno
join policy p on ur.pno = p.pno
where p.status = 'E' 
order by r.pno;

create or replace view Q7(pno, ptype, effectivedate, expirydate, agreedvalue) as
select distinct q7h.pno, p.ptype,p.effectivedate,p.expirydate, p.agreedvalue
from q7h 
join policy p on q7h.pno = p.pno
where q7h.days in (
        select max(days) from q7h
);

create or replace view Q8(pid, name, brand) as
select distinct per.pid,per.firstname||' '||per.lastname as "name", i.brand 
from policy p 
join insured_item i on i.id = p.id
join staff s on p.sid = s.sid
join person per on s.pid = per.pid
where p.sid in (
            select a.sid from (select distinct p.sid,i.brand from policy p join insured_item i on i.id = p.id where p.status = 'E') a 
            group by a.sid having count(*) = 1 
) order by per.pid;


create or replace view q9h(pid,brand) as 
select distinct per.pid, ii.brand from insured_by i 
join policy p on p.pno = i.pno 
join insured_item ii on ii.id = p.id
join client c on i.cid = c.cid
join person per on per.pid = c.pid
order by per.pid;


create or replace view q9h2(pid,brand) as 
select h.pid, count(distinct h.brand) as nbrands
from q9h h
group by pid;

create or replace view Q9(pid, name) as
select q9h2.pid, p.firstname||' '||p.lastname as "name" from q9h2
join person p on q9h2.pid = p.pid
where q9h2.brand in ((select count(*) as nbrands from (select distinct brand from insured_item) as a))
order by q9h2.pid;

create function
    staffcount(policyno integer) returns integer
as $$
declare stc integer;
declare flag integer;
begin
    select counts into stc
    from   (select count(distinct sid) as counts, pno from allStaffPno group by pno ) subq
    where subq.pno = policyno;
    select count(*) into flag
    from   (select count(distinct sid) as counts, pno from allStaffPno group by pno ) subq
    where subq.pno = policyno;
    if flag = 0 then
        return 0;
    else 
        return stc;
    end if;
end;
$$ language plpgsql;


create or replace function
    validRenewal(policyno integer) returns integer
as $$
declare 
    pexist integer;
    predundant integer;
    vehicleid integer;
    expirydate date; 
    pstatus character varying(2);
    poltype char(1);
begin
    select count(*) into pexist from policy p where p.pno = policyno;

    if pexist = 0 then
        return 0;
    end if;

    select p.id,p.status,p.expirydate,p.ptype  
    into vehicleid,pstatus,expirydate,poltype from policy p where p.pno = policyno;

    select count(*) into predundant from policy p 
    where p.pno <> policyno and p.status ='E' and p.expirydate-CURRENT_DATE >= 0 
    and p.id = vehicleid and p.ptype = poltype;

    if predundant <> 0 then
        return 0;
    end if;

    if (pstatus <> 'E' or expirydate-CURRENT_DATE < 0) then
        return 2;
    end if;

    return 1;

end;
$$ language plpgsql;

create or replace procedure renew(policyno integer)
as $$
declare 
tuple record;
new_pno integer;
new_coid integer;
validPol integer;
vehicleid integer;
polexpirydate date; 
effectivedate date;
pstatus character varying(2);
poltype char(1);
polvalue real;
pstaff integer;
polcomments character varying(80);

begin
    select validRenewal(policyno) into validPol;
    
    select max(pno)+1 into new_pno from policy;
    
    select max(coid)+1 into new_coid from coverage;
    
    select p.id,p.status,p.expirydate,p.ptype,p.agreedvalue,p.comments,p.sid,p.effectivedate  
    into vehicleid,pstatus,polexpirydate,poltype,polvalue,polcomments,pstaff,effectivedate 
    from policy p where p.pno = policyno;

    if validPol <> 0 then 
        insert into policy values (new_pno,poltype,'D',CURRENT_DATE,CURRENT_DATE + (polexpirydate-effectivedate),
        polvalue,polcomments,pstaff,vehicleid);
        
        if validPol <> 2 then
            update policy
            set expirydate = CURRENT_DATE
            where policy.pno = policyno;
        end if;

        FOR tuple IN
        SELECT * FROM coverage where coverage.pno = policyno
        LOOP
        INSERT INTO coverage VALUES (new_coid,tuple.cname,tuple.maxamount,tuple.comments,new_pno);
        new_coid := new_coid + 1;
        END LOOP;

    end if;

end;
$$ language plpgsql;

-- //////////////////////////////////////////TRIGGER helper functions/////////////////////////////////////////////
create or replace function
    ridToPno(rateid integer) returns integer
as $$
declare rpno integer;
        existance integer;

begin
    select count(*) into existance from rating_record r
    join coverage c on c.coid = r.coid
    where r.rid = rateid;

    if existance = 0 then
        raise exception 'supplied rid doesn''t exist';
    end if;

    select c.pno into rpno from rating_record r
    join coverage c on c.coid = r.coid
    where r.rid = rateid;

    return rpno;

end;
$$ language plpgsql;

create or replace function
    uridToPno(underid integer) returns integer
as $$
declare rpno integer;
        existance integer;

begin
    select count(*) into existance from underwriting_record ur
    where ur.urid = underid;

    if existance = 0 then
        raise exception 'supplied urid doesn''t exist';
    end if;

    select ur.pno into rpno from underwriting_record ur
    where ur.urid = underid;

    return rpno;

end;
$$ language plpgsql;

create or replace function
    sidToCid(ssid integer) returns integer
as $$
declare rcid integer;

begin

    select c.cid into rcid from client c
    join staff s on s.pid = c.pid
    where s.sid = ssid;


    return rcid;

end;
$$ language plpgsql;

create or replace function
    cidToSid(ccid integer) returns integer
as $$
declare rsid integer;

begin

    select s.sid into rsid from staff s
    join client c on s.pid = c.pid
    where c.cid = ccid;


    return rsid;

end;
$$ language plpgsql;

-- //////////////////////////////////////////TRIGGER functions/////////////////////////////////////////////

CREATE OR REPLACE FUNCTION policy_insert() 
   RETURNS TRIGGER 
   LANGUAGE PLPGSQL
AS $$
DECLARE 
ipno integer;
icid integer;
flag integer;
BEGIN

    select sidToCid(NEW.sid) into icid;
    ipno := NEW.pno;
    select count(*) into flag from insured_by ib
    where ipno = ib.pno and icid = ib.cid;

   IF (flag <> 0)
   THEN
     RAISE EXCEPTION 'Client from the same policy can''t sell the policy';
   END IF;
   
   RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION urb_insert()
   RETURNS TRIGGER 
   LANGUAGE PLPGSQL
AS $$
DECLARE 
ipno integer;
icid integer;
flag integer;
BEGIN

    select sidToCid(NEW.sid) into icid ;
    select uridToPno(NEW.urid) into ipno;

    select count(*) into flag from insured_by ib
    where ipno = ib.pno and icid = ib.cid;

   IF (flag <> 0)
   THEN
     RAISE EXCEPTION 'Client from the same policy can''t underwrite a policy';
   END IF;
   
   RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION rb_insert()
   RETURNS TRIGGER 
   LANGUAGE PLPGSQL
AS $$
DECLARE 
ipno integer;
icid integer;
flag integer;
BEGIN

    select sidToCid(NEW.sid) into icid;
    select ridToPno(NEW.rid) into ipno;

    select count(*) into flag from insured_by ib
    where ipno = ib.pno and icid = ib.cid;

   IF (flag <> 0)
   THEN
     RAISE EXCEPTION 'Client from the same policy can''t rate a policy';
   END IF;
   
   RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION ib_insert()
   RETURNS TRIGGER 
   LANGUAGE PLPGSQL
AS $$
DECLARE 
isid integer;
nostaff integer;
BEGIN

    select cidToSid(NEW.cid) into isid;

    select count(*) into nostaff from (
        select p.sid from policy p where p.pno = NEW.pno
        union
        select ub.sid from policy p 
        join underwriting_record ur on ur.pno = p.pno
        join underwritten_by ub on ub.urid = ur.urid
        where p.pno = NEW.pno
        union
        select rb.sid from policy p
        join coverage c on c.pno = p.pno
        join rating_record rr on c.coid = rr.coid
        join rated_by rb on rb.rid = rr.rid
        where p.pno = NEW.pno
    ) as asip    -- allStaffsInvolvedInPolicy
    where isid = asip.sid;

   IF (nostaff <> 0)
   THEN
     RAISE EXCEPTION 'Insured client is a staff that has underwritten, rated, or sold a policy. This is not allowed';
   END IF;
   
   RETURN NEW;
END;
$$;

-- //////////////////////////////////////////TRIGGERS/////////////////////////////////////////////

CREATE TRIGGER policy_insert_trig
BEFORE INSERT OR UPDATE
ON policy
FOR EACH ROW
EXECUTE PROCEDURE policy_insert();

CREATE TRIGGER urb_insert_trig
BEFORE INSERT OR UPDATE
ON underwritten_by
FOR EACH ROW
EXECUTE PROCEDURE urb_insert();

CREATE TRIGGER rb_insert_trig
BEFORE INSERT OR UPDATE
ON rated_by
FOR EACH ROW
EXECUTE PROCEDURE rb_insert();

CREATE TRIGGER ins_by
BEFORE INSERT OR UPDATE
ON insured_by
FOR EACH ROW
EXECUTE PROCEDURE ib_insert();




-- PLAYGROUND



/*

create view map(title, year, a1, a2) as
select DISTINCT m.title, m.year, a1.name, a2.name
FROM movie m
JOIN acting ag1 on ag1.movie_id = m.id
JOIN acting ag2 on ag2.movie_id = m.id
JOIN actor a1 on ag1.actor_id = a1.id
JOIN actor a2 on ag2.actor_id = a2.id
where a1.name != a2.name
order by m.id


# 1 jump    a1 & a2 in the same movie
select m1.a1, m1.title, m1.a2
from map m1
where m1.a1 = "" COLLATE NOCASE and m2.a2 = ""  COLLATE NOCASE

# 2 jump #a1 r | r a2
select  m1.a1, m1.title, m1.a2, m2.title, m2.a2
from map m1, map m2
where m1.a1 = "" COLLATE NOCASE and m1.a2 = m2.a1 and m2.a2 = "" COLLATE NOCASE

# 3 jump #a1 r | r t | t a2
select  m1.a1, m1.title, m1.a2, m2.title, m2.a2, m3.title, m3.a2
from map m1, map m2, map m3
where m1.a1 = "" COLLATE NOCASE and m1.a2 = m2.a1 and m2.a2 = m3.a1 and m3.a2 = "" COLLATE NOCASE

# 4 jump #a1 r | r t | t n | n a2
select  m1.a1, m1.title, m1.a2, m2.title, m2.a2, m3.title, m3.a2, m4.title, m4.a2
from map m1, map m2, map m3, map m4
where m1.a1 = "" COLLATE NOCASE and m1.a2 = m2.a1 and m2.a2 = m3.a1 and m3.a2 = m4.a1 and m4.a2 = "" COLLATE NOCASE

# 5 jump #a1 r | r t | t n | n z | z a2
select  m1.a1, m1.title, m1.a2, m2.title, m2.a2, m3.title, m3.a2, m4.title, m4.a2, m5.title, m5.a2
from map m1, map m2, map m3, map m4, map m5
where m1.a1 = "" COLLATE NOCASE and m1.a2 = m2.a1 and m2.a2 = m3.a1 and m3.a2 = m4.a1 and m4.a2 = m5.a1 and m5.a2 = "" COLLATE NOCASE

# 6 jump #a1 r | r t | t n | n z | z k | k a2
select  m1.a1, m1.title, m1.a2, m2.title, m2.a2, m3.title, m3.a2, m4.title, m4.a2, m5.title, m5.a2, m6.title, m6.a2
from map m1, map m2, map m3, map m4, map m5, map m6
where m1.a1 = "" COLLATE NOCASE and m1.a2 = m2.a1 and m2.a2 = m3.a1 and m3.a2 = m4.a1 and m4.a2 = m5.a1 and m5.a2 = m6.a1 and m6.a2 = "" COLLATE NOCASE

*/