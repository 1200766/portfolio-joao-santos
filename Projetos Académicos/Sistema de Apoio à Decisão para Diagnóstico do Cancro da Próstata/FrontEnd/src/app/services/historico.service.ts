import { Injectable } from '@angular/core';
import { HttpClient,HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Historico {
  _id?:'';
  consultas: '';
  respostas_questionario:''; 
}

@Injectable({
  providedIn: 'root'
})
export class HistoricoService {
private baseUrl = 'http://localhost:8080/med'; // adapta ao teu backend

  constructor(private http: HttpClient) {}

 
  getHistorico(historicoId: string): Observable<{ message: string, resultado: Historico[] }> {
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });

    return this.http.post<{ message: string, resultado: Historico[] }>(
      `${this.baseUrl}/Get/Historico`,
      { historicoId },
      { headers }
    );
  }
}
