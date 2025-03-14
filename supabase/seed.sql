
-- Notes Table
CREATE TABLE notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    title character varying(255) NOT NULL,
    description text,
    completed boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
    );


-- Add indexes for foreign keys and frequently searched columns
CREATE INDEX idx_notes_title ON notes(title);


ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- Notes policies (restricted to authenticated users only)
CREATE POLICY "Allow read access for authenticated users only" ON notes
    FOR SELECT TO authenticated
    USING (true);

    -- Allow users to manage their own notes
CREATE POLICY "Allow users to manage their own notes" ON notes
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
