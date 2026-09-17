import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
export interface Consulta {
  id: string; // Adiciona o id para manipulação
  data: string;
  medico: string;
  utenteId: string;
  especialidade?: string; // Use `?` se for opcional
}

@Injectable({
  providedIn: 'root'
})
export class ConsultasService {
  private baseUrl = 'http://localhost:8080/med'; // adapta ao teu backend

  constructor(private http: HttpClient) { }


  getConsultasDoMedico(medicoId: string): Observable<{ message: string, resultado: Consulta[] }> {
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });

    return this.http.post<{ message: string, resultado: Consulta[] }>(
      `${this.baseUrl}/Get/ListaConsultas`,
      { medicoId },
      { headers }
    );
  }
  getConsultas(historicoId: string): Observable<{ message: string, resultado: Consulta[] }> {
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });

    return this.http.post<{ message: string, resultado: Consulta[] }>(
      `${this.baseUrl}/Get/Consultas`,
      { historicoId },
      { headers }
    );
  }
  getConsultasDoUtente(utenteId: string): Observable<Consulta[]> {
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });    
    return this.http.get<Consulta[]>(`${this.baseUrl}/consultas/utente/${utenteId}`,  {headers});
  }

  eliminarConsulta(consultaId: string): Observable<any> {
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });

    return this.http.delete(`${this.baseUrl}/Delete/Consulta`, {
      headers,
      body: { consultaId }
    });
  }
}