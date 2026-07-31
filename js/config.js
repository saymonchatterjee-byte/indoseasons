// ---------------------------------------------------------------------------
// Supabase project config
// ---------------------------------------------------------------------------
// These two values are safe to expose in client-side code — they are not
// secrets. Row Level Security (RLS), set up in schema.sql, is what actually
// enforces who can read/write what. Never put your `service_role` key here.
//
// Get these from: Supabase Dashboard -> Settings -> API
// ---------------------------------------------------------------------------

const SUPABASE_URL = 'https://mcltojkfelafxstdswrj.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbHRvamtmZWxhZnhzdGRzd3JqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU0Mjk5MjgsImV4cCI6MjEwMTAwNTkyOH0.OaPTOIz0C4atV8SMHgptoCU19ah-N7rT-rj6hdq90lU';

// Creates one shared Supabase client for the whole site.
// Loaded via CDN in each HTML page before this script runs (see <script> tags).
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
