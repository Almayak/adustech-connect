import {useEffect,useMemo,useState} from 'react';
import {Link} from 'react-router-dom';
import {useAuth} from '../contexts/AuthContext';
import {supabase} from '../lib/supabase';

type Student={id:string;full_name:string;username:string;bio:string|null;level:string|null;avatar_url:string|null;faculty:{name:string}|null};

export default function DiscoverPage(){
  const {session}=useAuth();
  const [students,setStudents]=useState<Student[]>([]);
  const [query,setQuery]=useState('');
  const [faculty,setFaculty]=useState('');
  const [status,setStatus]=useState('');
  const [loading,setLoading]=useState(true);

  useEffect(()=>{
    let active=true;
    async function load(){
      if(!supabase||!session){setLoading(false);return;}
      setLoading(true);
      const {data,error}=await supabase.from('profiles').select('id,full_name,username,bio,level,avatar_url,faculty:faculties(name)').neq('id',session.user.id).order('full_name').limit(60);
      if(!active)return;
      setLoading(false);
      if(error){setStatus('Unable to load students. Please try again.');return;}
      setStudents((data??[]) as unknown as Student[]);
    }
    void load();
    return()=>{active=false};
  },[session]);

  const faculties=useMemo(()=>Array.from(new Set(students.map(s=>s.faculty?.name).filter(Boolean) as string[])).sort(),[students]);
  const filtered=students.filter(s=>{
    const text=`${s.full_name} ${s.username} ${s.bio??''} ${s.faculty?.name??''}`.toLowerCase();
    return (!query||text.includes(query.toLowerCase()))&&(!faculty||s.faculty?.name===faculty);
  });

  async function connect(id:string){
    if(!supabase)return;
    setStatus('Sending connection request…');
    const {error}=await supabase.rpc('send_connection_request',{target_user_id:id});
    setStatus(error?'Unable to send request. The profile may be unavailable or already connected.':'Connection request sent.');
  }

  return <section className="page"><div className="eyebrow">ADUSTECH Connect</div><h1>Discover students</h1><p>Find study partners and meaningful connections across the available student community.</p><div className="discover-controls"><input aria-label="Search students" placeholder="Search by name, username or interest" value={query} onChange={e=>setQuery(e.target.value)}/><select aria-label="Filter by faculty" value={faculty} onChange={e=>setFaculty(e.target.value)}><option value="">All available faculties</option>{faculties.map(name=><option key={name}>{name}</option>)}</select></div>{status&&<p className="form-status" role="status">{status}</p>}{loading&&<div className="empty-state"><p>Loading students…</p></div>} {!loading&&<div className="student-grid">{filtered.map(student=><article className="student-card" key={student.id}><div className="avatar">{student.full_name.slice(0,1).toUpperCase()}</div><h2>{student.full_name}</h2><p className="muted">@{student.username}{student.level&&` · ${student.level}`}</p>{student.faculty&&<p>{student.faculty.name}</p>}<p>{student.bio||'This student has not added a bio yet.'}</p><div className="actions"><Link className="secondary" to={`/profile/${encodeURIComponent(student.username)}`}>View profile</Link><button className="primary" onClick={()=>connect(student.id)}>Connect</button></div></article>)}</div>}{!loading&&!filtered.length&&<div className="empty-state"><h2>No students found</h2><p>There are no visible students matching your search yet.</p></div>}</section>
}