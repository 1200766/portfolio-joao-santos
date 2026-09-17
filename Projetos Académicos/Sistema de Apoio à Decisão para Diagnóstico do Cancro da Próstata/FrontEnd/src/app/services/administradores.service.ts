import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';


export interface User {
   _id: '',
  nome: '',
  contacto: '',
  genero: '',
  nascimento: '',
  password: '',
  email: '',
  username: '',
  isAdmin:boolean

}

@Injectable({
  providedIn: 'root'
})
export class AdministradoresService {
  private baseUrl = 'http://localhost:8080/med';
  filtroNome: string = '';
  constructor(private http: HttpClient) { }
  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('userToken');
    return new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json'
    });
  }
  getUser(): Observable<User[]> {
    return this.http.get<User[]>(`${this.baseUrl}/Get/Adminitradores`, {
      headers: this.getHeaders()
    });
  }

  getUsers(): Observable<User[]> {
    return this.http.get<User[]>(`${this.baseUrl}/Get/Users`, {
      headers: this.getHeaders()
    });
  }
  registarUser(dados: any) {
    return this.http.post(`${this.baseUrl}/Register/User`, dados, {
      headers: this.getHeaders()
    });
  }

  atualizarUser(user: User) {
    const payload = {
      userid: user._id,
      nome: user.nome,
      dataNascimento: user.nascimento,
      contacto: user.contacto,
      genero: user.genero
    };
    return this.http.put(`${this.baseUrl}/Update/User`, payload, {
      headers: this.getHeaders()
    });
  }

  deleteUser(username: string) {
    return this.http.request('delete', `${this.baseUrl}/Delete/User`, {
      body: { username },
      headers: this.getHeaders()
    });
  }
}

