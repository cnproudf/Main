// ============================================================================
// PIECE 1 of 3: THE CONNECTOR
// ----------------------------------------------------------------------------
// This file opens a line to your Supabase project. It reads the two values from
// your .env.local file (never hard-coded here, never committed to git):
//   * NEXT_PUBLIC_SUPABASE_URL      -- your project's web address
//   * NEXT_PUBLIC_SUPABASE_ANON_KEY -- the PUBLIC key, safe for browsers
//
// "createClient" hands back an object we can ask questions with, like
// supabase.from('...').select('...'). We make it once and reuse it everywhere.
// ============================================================================
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
)
