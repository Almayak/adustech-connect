import {useEffect,useState} from 'react';
import {Link,useParams} from 'react-router-dom';
import {supabase} from '../lib/supabase';

type Profile={full_name:string;username:string;bio:string|null;level:string|null;avatar_url:string|null;faculty:{name:string}|null;department:{name:string}|null};
export default function PublicProfilePage(){
 const{username}=useParams();const[profile,setProfile]=useState<Profile|null>(null);const[loading,setLoading]=useState(true);const[error,setError]=useState('');
 useEffect(()=>{let active=true;async function load(){if(!supabase||!username){setLoading(false);return}const{data,error}=await supabase.from('profiles').select('full_name,username,bio,level,avatar_url,faculty:faculties(name),department:departments(name)').eq('username',username).maybeSingle();if(!active)return;setLoading(false);if(error||!data){setError('This profile is unavailable.');return}setProfile(data as unknown as Profile)}void load();return()=>{active=false}},[username]);
 if(loading)return <main className="page"><div className="empty-state"><p>Loading profile…</p></div></main>;
 if(error||!profile)return <main className="page"><div className="empty-state"><h1>Profile unavailable</h1><p>This profile may be private or no longer exists.</p><Link className="secondary" to="/discover">Back to Discover</Link></div></main>;
 return <main className="page"><Link className="secondary" to="/discover">← Discover</Link><article className="public-profile"><div className="avatar">{profile.full_name.slice(0,1).toUpperCase()}</div><h1>{profile.full_name}</h1><p className="muted">@{profile.username}</p>{profile.faculty&&<p>{profile.faculty.name}</p>}{profile.department&&<p>{profile.department.name}</p>}{profile.level&&<p>{profile.level}</p>}<p>{profile.bio||'This student has not added a bio yet.'}</p><p className="muted">ADUSTECH Connect is an independent student platform.</p></article></main>
}