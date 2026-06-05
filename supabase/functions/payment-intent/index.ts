import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
// 🚨 FIX 1: Use the native npm specifier instead of esm.sh
import Stripe from 'npm:stripe@^14.0.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') as string, {
      apiVersion: '2023-10-16', // Standardized version for v14
      // 🚨 FIX 2: Tell Stripe to use Deno's native fetch API, bypassing Node compatibility bugs
      httpClient: Stripe.createFetchHttpClient(),
    })

    const { amount } = await req.json()

    if (!amount || isNaN(amount)) {
      throw new Error('Invalid or missing amount parameter')
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100),
      currency: 'egp',
    })

    return new Response(
      JSON.stringify({
        clientSecret: paymentIntent.client_secret,
        transactionId: paymentIntent.id
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})