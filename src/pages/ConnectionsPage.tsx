import {useEffect,useState} from 'react';
import {useAuth} from '../contexts/AuthContext';
import {supabase} from '../lib/supabase';

type Row={id:string;requester_id:string;recipient_id:string;status:'pending'|'accepted'|'declined'|'blocked';requester:{full_name:string;username:string}|null;recipient:{full_name:string;username:string}|null};

export default function ConnectionsPage(){
  const{session}=useAuth();
  const[rows,setRows]=useState<Row[]>([]);
  const[status,setStatus]=useState('');
  const[loading,setLoading]=useState(true);
  const load=async()=>{if(!supabase||!session){setLoading(false);return}setLoading(true);const{data,error}=await supabase.from('connections').select('id,requester_id,recipient_id,status,requester:profiles!connections_requester_id_fkey(full_name,username),recipient:profiles!connections_recipient_id_fkey(full_name,username)').or(`requester_id.eq.${session.user.id},recipient_id.eq.${session.user.id}`).order('created_at',{ascending:false});setLoading(false);if(error)setStatus('Unable to load connections. Please try again.');else setRows((data??[]) as unknown as Row[])};
  useEffect(()=>{void load()},[session]);
  async function respond(id:string,next:'accepted'|'declined'){if(!supabase)return;setStatus('Updating request…');const{error}=await supabase.rpc('respond_to_connection',{connection_id:id,next_status:next});setStatus(error?'Unable to update this request.':'Request updated.');if(!error)void load()}
  async function remove(id:string){if(!supabase)return;setStatus('Removing connection…');const{error}=await supabase.rpc('remove_connection',{connection_id:id});setStatus(error?'Unable to remove this connection.':'Connection removed.');if(!error)void load()}
  const pending=rows.filter(r=>r.status==='pending');const accepted=rows.filter(r=>r.status==='accepted');const person=(r:Row)=>r.requester_id===session?.user.id?r.recipient:r.requester;
  return <section className="page"><div className="eyebrow">Your network</div><h1>Connections</h1><p>Manage requests and keep track of your accepted connections.</p>{status&&<p className="form-status" role="status">{status}</p>}{loading&&<div className="empty-state"><p>Loading connections…</p></div>} {!loading&&<><div className="connection-section"><h2>Pending requests</h2>{pending.length?pending.map(r=><article className="connection-card" key={r.id}><div><strong>{person(r)?.full_name||'Student'}</strong><span>@{person(r)?.username||'student'}</span></div>{r.recipient_id===session?.user.id?<div className="actions"><button className="primary" onClick={()=>respond(r.id,'accepted')}>Accept</button><button className="secondary" onClick={()=>respond(r.id,'declined')}>Decline</button></div>:<span className="muted">Awaiting response</span>}</article>):<div className="empty-state"><p>No pending connection requests.</p></div>}</div><div className="connection-section"><h2>Accepted connections</h2>{accepted.length?accepted.map(r=><article className="connection-card" key={r.id}><div><strong>{person(r)?.full_name||'Student'}</strong><span>@{person(r)?.username||'student'}</span></div><button className="secondary" onClick={()=>remove(r.id)}>Remove</button></article>):<div className="empty-state"><p>Your accepted connections will appear here.</p></div>}</div></>}</section>
}