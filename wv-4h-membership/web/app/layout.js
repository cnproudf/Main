// The outer shell every page sits inside. Nothing interesting here on purpose --
// it just provides the <html> and <body> wrapper and the browser-tab title.
export const metadata = {
  title: 'WV 4-H All Stars — Membership (sandbox)',
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body style={{ fontFamily: 'system-ui, sans-serif', margin: '2rem', lineHeight: 1.5 }}>
        {children}
      </body>
    </html>
  )
}
