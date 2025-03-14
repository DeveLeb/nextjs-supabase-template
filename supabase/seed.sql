-- Create ENUM types
CREATE TYPE event_status AS ENUM ('UPCOMING', 'COMPLETED', 'CANCELLED');
CREATE TYPE location_type AS ENUM ('ONSITE', 'REMOTE', 'HYBRID');
CREATE TYPE user_role AS ENUM ('USER', 'ADMIN');
CREATE TYPE job_level AS ENUM ('JUNIOR', 'MID-LEVEL', 'SENIOR', 'LEAD', 'MANAGER');
CREATE TYPE job_type AS ENUM ('FULL-TIME', 'PART-TIME', 'CONTRACT', 'TEMPORARY', 'INTERNSHIP');

-- Industries table for normalization
CREATE TABLE industries (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying(100) NOT NULL UNIQUE,
    created_at timestamp with time zone DEFAULT now()
);

-- Tags table for normalization
CREATE TABLE tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying(100) NOT NULL UNIQUE,
    created_at timestamp with time zone DEFAULT now()
);

-- Job related tables with improvements
CREATE TABLE job_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying(100) NOT NULL UNIQUE,
    created_at timestamp with time zone DEFAULT now()
);


-- Company table
CREATE TABLE companies (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying(255) NOT NULL UNIQUE,
    description text,
    email character varying(255) UNIQUE,
    phone character varying(15),
    website character varying(255) UNIQUE,
    size character varying(15),
    industry_id uuid REFERENCES industries(id),
    is_visible boolean DEFAULT false,
    instagram_url character varying(255),
    facebook_url character varying(255),
    x_url character varying(255),
    linkedin_url character varying(255),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Company feedback with improvements
CREATE TABLE company_feedback (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    description text NOT NULL,
    rating integer CHECK (rating BETWEEN 1 AND 5),
    approved boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Event table with improvements
CREATE TABLE events (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    title character varying(255) NOT NULL,
    description text,
    video_link character varying(255),
    flyer_link character varying(255),
    start_date timestamp with time zone NOT NULL,
    end_date timestamp with time zone NOT NULL,
    location character varying(255),
    location_type location_type DEFAULT 'ONSITE',
    speaker_name character varying(255),
    speaker_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    max_participants integer,
    status event_status DEFAULT 'UPCOMING',
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CHECK (end_date > start_date)
);

-- Event tags relation
CREATE TABLE event_tags (
    event_id uuid REFERENCES events(id) ON DELETE CASCADE,
    tag_id uuid REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (event_id, tag_id)
);


-- Events users registration table
CREATE TABLE event_users (
    event_id uuid REFERENCES events(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    registered_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (event_id, user_id)
);


-- Job table with improvements
CREATE TABLE jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    title character varying(255) NOT NULL,
    description text,
    company_id uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    location character varying(255),
    location_type location_type DEFAULT 'ONSITE',
    job_level job_level DEFAULT 'MID-LEVEL',
    job_type job_type DEFAULT 'FULL-TIME',
    category_id uuid NOT NULL REFERENCES job_categories(id),
    min_salary numeric(10,2),
    max_salary numeric(10,2),
    currency character varying(3) DEFAULT 'USD',
    application_link character varying(255),
    is_external boolean DEFAULT false,
    is_visible  boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CHECK (min_salary <= max_salary)
);


-- Job views tracking table
CREATE TABLE job_views (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    job_id uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,  -- NULL for anonymous users
    is_anonymous boolean DEFAULT true,
    ip_address inet,  -- Store IP address for analytics
    user_agent text,  -- Store user agent for analytics
    viewed_at timestamp with time zone DEFAULT now()
);


-- Job tags relation
CREATE TABLE job_tags (
    job_id uuid REFERENCES jobs(id) ON DELETE CASCADE,
    tag_id uuid REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (job_id, tag_id)
);


CREATE TABLE profiles (
    id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    role user_role DEFAULT 'USER',
    full_name character varying(255),
    phone_number character varying(20),
    profile_url text,
    category_id uuid REFERENCES job_categories(id) ON DELETE SET NULL,
    job_level job_level DEFAULT 'MID-LEVEL',
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


-- User tags relation
CREATE TABLE profile_tags (
    profile_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
    tag_id uuid REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (profile_id, tag_id)
);

-- Add indexes for foreign keys and frequently searched columns
CREATE INDEX idx_companies_industry ON companies(industry_id);
CREATE INDEX idx_jobs_company ON jobs(company_id);
CREATE INDEX idx_jobs_category ON jobs(category_id);
CREATE INDEX idx_job_views_job ON job_views(job_id);
CREATE INDEX idx_event_users_event ON event_users(event_id);
CREATE INDEX idx_companies_name ON companies(name);
CREATE INDEX idx_jobs_title ON jobs(title);
CREATE INDEX idx_events_dates ON events(start_date, end_date);
CREATE INDEX idx_company_feedback_rating ON company_feedback(company_id, rating);

ALTER TABLE industries ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_views ENABLE ROW LEVEL SECURITY;


CREATE OR REPLACE FUNCTION is_claims_admin() RETURNS "bool"
  LANGUAGE "plpgsql" 
  AS $$
  BEGIN
    IF session_user = 'authenticator' THEN
      --------------------------------------------
      -- To disallow any authenticated app users
      -- from editing claims, delete the following
      -- block of code and replace it with:
      -- RETURN FALSE;
      --------------------------------------------
      IF extract(epoch from now()) > coalesce((current_setting('request.jwt.claims', true)::jsonb)->>'exp', '0')::numeric THEN
        return false; -- jwt expired
      END IF;
      If current_setting('request.jwt.claims', true)::jsonb->>'role' = 'service_role' THEN
        RETURN true; -- service role users have admin rights
      END IF;
      IF coalesce((current_setting('request.jwt.claims', true)::jsonb)->'app_metadata'->'claims_admin', 'false')::bool THEN
        return true; -- user has claims_admin set to true
      ELSE
        return false; -- user does NOT have claims_admin set to true
      END IF;
      --------------------------------------------
      -- End of block 
      --------------------------------------------
    ELSE -- not a user session, probably being called from a trigger or something
      return true;
    END IF;
  END;
$$;

CREATE OR REPLACE FUNCTION get_my_claims() RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    AS $$
  select 
  	coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb -> 'app_metadata', '{}'::jsonb)::jsonb
$$;
CREATE OR REPLACE FUNCTION get_my_claim(claim TEXT) RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    AS $$
  select 
  	coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb -> 'app_metadata' -> claim, null)
$$;

CREATE OR REPLACE FUNCTION get_claims(uid uuid) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER SET search_path = public
    AS $$
    DECLARE retval jsonb;
    BEGIN
      IF NOT is_claims_admin() THEN
          RETURN '{"error":"access denied"}'::jsonb;
      ELSE
        select raw_app_meta_data from auth.users into retval where id = uid::uuid;
        return retval;
      END IF;
    END;
$$;

CREATE OR REPLACE FUNCTION get_claim(uid uuid, claim text) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER SET search_path = public
    AS $$
    DECLARE retval jsonb;
    BEGIN
      IF NOT is_claims_admin() THEN
          RETURN '{"error":"access denied"}'::jsonb;
      ELSE
        select coalesce(raw_app_meta_data->claim, null) from auth.users into retval where id = uid::uuid;
        return retval;
      END IF;
    END;
$$;

CREATE OR REPLACE FUNCTION set_claim(uid uuid, claim text, value jsonb) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER SET search_path = public
    AS $$
    BEGIN
      IF NOT is_claims_admin() THEN
          RETURN 'error: access denied';
      ELSE        
        update auth.users set raw_app_meta_data = 
          raw_app_meta_data || 
            json_build_object(claim, value)::jsonb where id = uid;
        return 'OK';
      END IF;
    END;
$$;

CREATE OR REPLACE FUNCTION delete_claim(uid uuid, claim text) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER SET search_path = public
    AS $$
    BEGIN
      IF NOT is_claims_admin() THEN
          RETURN 'error: access denied';
      ELSE        
        update auth.users set raw_app_meta_data = 
          raw_app_meta_data - claim where id = uid;
        return 'OK';
      END IF;
    END;
$$;
NOTIFY pgrst, 'reload schema';


CREATE OR REPLACE FUNCTION public.create_profile_after_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Insert a new profile for the user after sign up
  INSERT INTO public.profiles (id, role, full_name, category_id, job_level, phone_number)
  VALUES (NEW.id, 'USER', NEW.raw_user_meta_data->>'full_name',   (NEW.raw_user_meta_data->>'category_id')::text::uuid,
  (NEW.raw_user_meta_data->>'job_level')::public.job_level, NEW.raw_user_meta_data->>'phone_number');  
  -- Call set_claim function with the correct argument types
  PERFORM public.set_claim(NEW.id, 'role', '"USER"'::jsonb);
  RETURN NEW;
END;
$$;

-- Create the trigger on the users table
CREATE TRIGGER trigger_create_profile_after_signup
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.create_profile_after_signup();



-- Industries policies
CREATE POLICY "Allow read access for all users" ON industries
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY "Allow write access for admins" ON industries
    FOR ALL TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);

-- Tags policies
CREATE POLICY "Allow read access for all users" ON tags
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY "Allow write access for admins" ON tags
    FOR ALL TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);

-- Companies policies
CREATE POLICY "Allow read access for all users" ON companies
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY "Allow write access for admins" ON companies
    FOR ALL TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);

-- Company_feedback policies
CREATE POLICY "Allow read access for all users" ON company_feedback
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY "Allow users to insert feedback" ON company_feedback
    FOR INSERT TO authenticated
    WITH CHECK (true);

CREATE POLICY "Allow admins to update and delete feedback" ON company_feedback
    FOR UPDATE TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);

CREATE POLICY "Allow admins to delete feedback" ON company_feedback
    FOR DELETE TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb);

-- Events policies
CREATE POLICY "Allow read access for all users" ON events
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY "Allow write access for admins" ON events
    FOR ALL TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);

-- Event_tags policies
CREATE POLICY "Allow read access for all users" ON event_tags
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY "Allow write access for admins" ON event_tags
    FOR ALL TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);

-- Job_categories policies
CREATE POLICY "Allow read access for all users" ON job_categories
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY "Allow write access for admins" ON job_categories
    FOR ALL TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);


-- Jobs policies
CREATE POLICY "Allow read access for all users" ON jobs
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY "Allow write access for admins" ON jobs
    FOR ALL TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);

-- Job_tags policies
CREATE POLICY "Allow read access for all users" ON job_tags
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY "Allow write access for admins" ON job_tags
    FOR ALL TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);

-- profile_tags policies
CREATE POLICY "Allow users to manage their own profile tags" ON profile_tags
    FOR ALL TO authenticated
    USING (profile_id = auth.uid())
    WITH CHECK (profile_id = auth.uid());

CREATE POLICY "Allow write access for admins" ON profile_tags
    FOR ALL TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);



-- Profiles policies (restricted to authenticated users only)
CREATE POLICY "Allow read access for authenticated users only" ON profiles
    FOR SELECT TO authenticated
    USING (true);

    -- Allow users to manage their own profile
CREATE POLICY "Allow users to manage their own profile" ON profiles
    FOR ALL TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

CREATE POLICY "Allow write access for admins" ON profiles
    FOR ALL TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);

-- Event_users policies
CREATE POLICY "Allow read access for registered users" ON event_users
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "Allow users to manage their own event registrations" ON event_users
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Allow write access for admins" ON event_users
    FOR ALL TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb)
    WITH CHECK (get_my_claim('role') = '"ADMIN"'::jsonb);


-- Job_views policies
CREATE POLICY "Allow insert access for all users" ON job_views
    FOR INSERT TO anon, authenticated
    WITH CHECK (true);

CREATE POLICY "Allow read access for admins" ON job_views
    FOR SELECT TO authenticated
    USING (get_my_claim('role') = '"ADMIN"'::jsonb);
