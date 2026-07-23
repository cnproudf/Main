// ============================================================================
// PIECES 2 and 3 of 3: THE QUESTION and THE DISPLAY
// ----------------------------------------------------------------------------
// 'use client' means this page runs in the visitor's browser, so it can react
// to typing in the search box. It uses the connector from lib/supabaseClient.js.
// ============================================================================
'use client'

import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'

export default function Page() {
  // "state" = little boxes the page remembers and re-draws when they change.
  const [members, setMembers] = useState([]) // the rows we got from the database
  const [search, setSearch] = useState('')   // whatever is typed in the search box
  const [status, setStatus] = useState('Loading members…')

  // ----- PIECE 2: THE QUESTION --------------------------------------------
  // Runs once when the page opens. It asks the eligibility VIEW for a few
  // columns, sorted by member id. Note we read the VIEW, not the raw tables --
  // so the browser never even sees the sensitive "reason" text, and the
  // eligible/not-eligible verdict is the one the database calculated.
  useEffect(() => {
    async function load() {
      const { data, error } = await supabase
        .from('member_voting_eligibility')
        .select('member_id, first_name, last_name, voting_eligible, eligibility_basis')
        .order('member_id')

      if (error) {
        setStatus('Could not load data: ' + error.message)
        return
      }
      setMembers(data)
      setStatus('')
    }
    load()
  }, [])

  // Filter in the browser: keep rows whose name or id contains the search text.
  // (Simple version: we already have all 15 rows, so we just hide non-matches.
  //  The sophisticated version would ask the database to search -- overkill here.)
  const term = search.trim().toLowerCase()
  const shown = members.filter((m) => {
    const haystack = `${m.first_name} ${m.last_name} ${m.member_id}`.toLowerCase()
    return haystack.includes(term)
  })

  // ----- PIECE 3: THE DISPLAY ---------------------------------------------
  return (
    <main>
      <h1>WV 4-H All Stars — Membership (sandbox)</h1>
      <p style={{ color: '#555' }}>
        Invented sample data. Each verdict below was calculated by the database, not typed in.
      </p>

      <input
        type="text"
        placeholder="Search by name or member id…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ padding: '0.5rem', width: '20rem', marginBottom: '1rem' }}
      />

      {status && <p>{status}</p>}

      <table cellPadding="6" style={{ borderCollapse: 'collapse', width: '100%' }}>
        <thead>
          <tr style={{ textAlign: 'left', borderBottom: '2px solid #333' }}>
            <th>Member</th>
            <th>ID</th>
            <th>Eligible to vote?</th>
            <th>Reason</th>
          </tr>
        </thead>
        <tbody>
          {shown.map((m) => (
            <tr key={m.member_id} style={{ borderBottom: '1px solid #ccc' }}>
              <td>{m.first_name} {m.last_name}</td>
              <td>{m.member_id}</td>
              <td>{m.voting_eligible ? '✅ Yes' : '❌ No'}</td>
              <td>{m.eligibility_basis}</td>
            </tr>
          ))}
        </tbody>
      </table>

      {!status && (
        <p style={{ color: '#555', marginTop: '1rem' }}>
          Showing {shown.length} of {members.length} members.
        </p>
      )}
    </main>
  )
}
