import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Router } from '@angular/router';
import { Observable, of, switchMap, map } from 'rxjs';

export interface User {
  _id: '',
  nome: '',
  contacto: '',
  genero: '',
  nascimento: '',
  password: '',
  email: '',
  username: '',
  isAdmin: boolean

}

@Injectable({
  providedIn: 'root',
})
export class AuthService {

  private userToken: string = '';
  private userId: string = '';
  private userType: string = '';
  private currentUser: User | null = null;
  private baseUrl = 'http://localhost:8080/med';

  constructor(private http: HttpClient, private router: Router) { }

  login(identificador: string, password: string): Observable<any> {
    const headers = new HttpHeaders({ 'Content-Type': 'application/json' });
    const body = JSON.stringify({ identificador, password });

    return this.http.post(`${this.baseUrl}/login`, body, { headers }).pipe(
      map((response: any) => {
        if (response?.token && response?.user && response?.role) {
          this.userToken = response.token;
          this.userId = response.user._id;
          this.userType = response.role;
          this.currentUser = response.user;

          // Guardar localmente
          localStorage.setItem('userToken', this.userToken);
          localStorage.setItem('userId', this.userId);
          localStorage.setItem('userType', this.userType);
          localStorage.setItem('auth_user', JSON.stringify(this.currentUser));

          return response;
        }

        return null;
      })
    );
  }
  getUserAssociation(userId: string): Observable<{ tipo: string; id: string }> {
    const token = localStorage.getItem('auth_token');
    const headers = new HttpHeaders({
      'x-access-token': token || '',
      'Content-Type': 'application/json',
    });

    return this.http.post<{ tipo: string; id: string }>(
      `${this.baseUrl}/getAssociation`,
      { userId },
      { headers }
    );
  }

  saveToken(token: string) {
    localStorage.setItem('auth_token', token);
  }

  setUser(user: User) {
    this.currentUser = user;
    localStorage.setItem('auth_user', JSON.stringify(user));
  }
  getUserType(): string | null {
    return localStorage.getItem('userType');
  }
  getUser(): User | null {
    if (this.currentUser) return this.currentUser;

    const userJson = localStorage.getItem('auth_user');
    if (userJson) {
      this.currentUser = JSON.parse(userJson);
      return this.currentUser;
    }
    return null;
  }

  logout() {
    localStorage.removeItem('auth_token');
    localStorage.removeItem('userToken');
    localStorage.removeItem('userId');
    localStorage.removeItem('userType');
    localStorage.removeItem('auth_user');
    this.currentUser = null;
    this.router.navigate(['/login']);
  }
  isLoggedIn(): boolean {
    const token = localStorage.getItem('auth_token');
    // Opcional: podes decodificar o JWT e verificar expiração
    return !!token;
  }
}
