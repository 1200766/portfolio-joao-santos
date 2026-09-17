import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Resposta {
  _id?: '';
  utilizador: '';
  questionario: '';
  respostas: {
    idpergunta: '';
    idresposta: '';
  }[];

}
@Injectable({
  providedIn: 'root'
})
export class RespostasService {

  private baseUrl = 'http://localhost:8080/med'; // ajuste para sua API

  constructor(private http: HttpClient) { }
  registarResposta(dados: any) {
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });
    return this.http.post(`${this.baseUrl}/Register/Resposta`, dados, { headers });
  }

   obterRespostas(utenteId: string, questionarioId: string): Observable<any> {
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });
    return this.http.post<any>(
      `${this.baseUrl}/Get/Respostas`,
      { userId: utenteId, questionarioId },
      { headers }
    );
  }

  obterQuestionario(questionarioId: string, perguntaId: string, respostaId: string): Observable<any> {
    const token = localStorage.getItem('userToken');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });
    return this.http.post<any>(
      `${this.baseUrl}/Get/Questionario`,
      { questionarioId, perguntaId, respostaId },
      { headers }
    );
  }
}