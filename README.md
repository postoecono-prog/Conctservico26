# Conecta Serviços V2

## Incluído
- HTML/CSS/JavaScript responsivo.
- Login, cadastro e recuperação de senha via Supabase Auth.
- Perfis de cliente, profissional e administrador.
- Taxa manual de ativação de R$ 4,99 via WhatsApp do ADM.
- Liberação por 30 dias através de função SQL protegida por RLS.
- Solicitações de orçamento e controle de status.
- Lista de profissionais somente com assinatura ativa.

## Configuração
1. Crie um projeto em https://supabase.com.
2. Execute `supabase-schema.sql` no SQL Editor.
3. Abra `index.html` e preencha `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
4. Crie um usuário e faça login uma vez.
5. Execute no SQL Editor:
```sql
update public.profiles set role='admin', status='active' where email='SEU_EMAIL_ADMIN@EXEMPLO.COM';
```
6. Publique `index.html` no GitHub Pages.

## Fluxo profissional
O profissional se cadastra como `pending`, fala com o ADM, paga R$ 4,99 e envia o comprovante. O ADM confirma manualmente no painel. A função `admin_activate_professional` libera o acesso por 30 dias.

## Segurança
- Nunca use `service_role key` no navegador.
- RLS é habilitado nas tabelas.
- A função de ativação valida o administrador no banco.
- Configure Site URL e Redirect URLs no Supabase Authentication.
- Antes de produção, teste as políticas RLS e configure termos, privacidade e confirmação de e-mail.
