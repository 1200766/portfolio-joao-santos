import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Medico {
  id: '',
  nome: '',
  contacto: '',
  genero: '',
  nascimento: '',
  proximaConsulta: '',
  password: '',
  email: '',
  username: '',
  specialty: ''

}

@Injectable({
  providedIn: 'root'
})
export class MedicosService {
  private apiUrl = 'http://localhost:8080/med/Get/Medicos'; // ajuste conforme necessário

  constructor(private http: HttpClient) { }

    getMedicos(): Observable<Medico[]> {
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });
    return this.http.get<Medico[]>(this.apiUrl, { headers });
  }

  registarMedico(dados: any) {
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });
    return this.http.post('http://localhost:8080/med/Register/Medico', dados, { headers });
  }

  atualizarMedico(medico: Medico) {
    const payload = {
      id: medico.id,
      nome: medico.nome,
      dataNascimento: medico.nascimento,
      contacto: medico.contacto,
      genero: medico.genero,
      specialty: medico.specialty,
    };
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });
    return this.http.put('http://localhost:8080/med/Update/Medico', payload, { headers });
  }

  deleteMedico(username: string) {
    const url = 'http://localhost:8080/med/Delete/User';
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });
    return this.http.request('delete', url, {
      headers,
      body: { username }
    });
  }
}