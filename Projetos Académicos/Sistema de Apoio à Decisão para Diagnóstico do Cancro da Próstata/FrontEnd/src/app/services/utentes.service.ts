import { Injectable } from '@angular/core';
import { HttpClient ,HttpHeaders} from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Utente {
  id: '',
  user:'',
  nome: '',
  numeroUtente: '',
  contacto: '',
  genero: '',
  nascimento: '',
  proximaConsulta: '',
  medico: '',
  medicoid: '',
  password: '',
  email: '',
  username: '',
  historicoId: '',
  userId:'',
  alert:''

}

@Injectable({
  providedIn: 'root'
})
export class UtentesService {
  private apiUrl = 'http://localhost:8080/med';

  constructor(private http: HttpClient) { }
  
  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('userToken');
    return new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json'
    });
  }

  getUtentes(): Observable<Utente[]> {
    return this.http.get<Utente[]>(`${this.apiUrl}/Get/Utentes`, {
      headers: this.getHeaders()
    });
  }
  deleteUtente(username: string) {
    const url = `${this.apiUrl}/Delete/User`;
    return this.http.request('delete', url, {
      body: { username },
      headers: this.getHeaders()
    });
  }

  atualizarUtente(utente: Utente) {
    const payload = {
      utenteId: utente.id,
      nome: utente.nome,
      dataNascimento: utente.nascimento,
      contacto: utente.contacto,
      genero: utente.genero,
      numeroUtenteSaude: utente.numeroUtente,
      medico: utente.medicoid
    };
    return this.http.put(`${this.apiUrl}/Update/Utente`, payload, {
      headers: this.getHeaders()
    });
  }
  registarUtente(dados: any) {
    return this.http.post(`${this.apiUrl}/Register/Utente`, dados, {
      headers: this.getHeaders()
    });
  }

  registarConsulta(consulta: any) {
    return this.http.post(`${this.apiUrl}/Register/Consulta`, consulta, {
      headers: this.getHeaders()
    });
  }
}







