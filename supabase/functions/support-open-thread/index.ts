// Opens a support thread for the signed-in user: a conversation, its participant
// row and a support ticket. Called by lib/screens/support_chat_screen.dart with
// { subject } and expected to return { conversation_id, ticket_id }.
import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '')
    const { data: { user }, error: authError } = await admin.auth.getUser(token)
    if (authError || !user) return json({ error: 'Not authenticated' }, 401)

    const { subject } = await req.json().catch(() => ({ subject: null }))

    const { data: convo, error: convoError } = await admin
      .from('conversations')
      .insert({ type: 'support' })
      .select('id')
      .single()
    if (convoError) throw convoError

    const { error: partError } = await admin
      .from('conversation_participants')
      .insert({ conversation_id: convo.id, user_id: user.id })
    if (partError) throw partError

    const { data: ticket, error: ticketError } = await admin
      .from('support_tickets')
      .insert({
        user_id: user.id,
        conversation_id: convo.id,
        subject: subject || 'New support request',
      })
      .select('id')
      .single()
    if (ticketError) throw ticketError

    return json({ conversation_id: convo.id, ticket_id: ticket.id })
  } catch (error) {
    return json({ error: (error as Error).message }, 400)
  }
})
