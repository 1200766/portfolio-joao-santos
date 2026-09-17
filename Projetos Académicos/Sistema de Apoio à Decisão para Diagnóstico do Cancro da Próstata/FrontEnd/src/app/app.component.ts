import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { AuthService, User } from './services/auth.service';


@Component({
  selector: 'app-root',
  imports:[RouterModule, CommonModule, FormsModule,CommonModule],
    standalone: true,

  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  title = 'Sistema de Apoio à Decisão para Diagnóstico do Cancro da Próstata';
  constructor(private authService: AuthService) {}

  ngOnInit(): void {
    const user = this.authService.getUser();
    const token = localStorage.getItem('auth_token');

    if (user && token) {
      this.authService.setUser(user); // repõe o utilizador na memória
    } else {
      // opcional: redirecionar para login
    }
  }
}
